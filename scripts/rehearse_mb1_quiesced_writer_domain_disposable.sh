#!/usr/bin/env bash
# M1-04: controlled writer shutdown and readonly filesystem snapshot.
# Disposable Docker network, PostgreSQL, worker and synthetic files only.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
if [ "\${MB1_QUIESCED_WRITER_LAB:-}" != YES ]; then
  echo "MB1_QUIESCED_WRITER_OPT_IN=REQUIRED"; exit 2
fi
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
root="$(mktemp -d /tmp/mb1-writer-domain.XXXXXXXX)"
suffix="$$_$RANDOM"
network="mb1_domain_net_$suffix"
db="mb1_domain_pg_$suffix"
writer="mb1_domain_writer_$suffix"
made_net=0
made_db=0
made_writer=0
cleanup() {
  code=$?
  trap - EXIT
  if [ "$made_writer" = 1 ]; then docker rm -f "$writer" >/dev/null 2>&1 || code=1; fi
  if [ "$made_db" = 1 ]; then docker rm -f "$db" >/dev/null 2>&1 || code=1; fi
  if [ "$made_net" = 1 ]; then docker network rm "$network" >/dev/null 2>&1 || code=1; fi
  rm -rf -- "$root" || code=1
  echo "MB1_DOMAIN_ISOLATION_RESULT=$code"
  echo "MB1_SQL_SUPERUSER_BYPASS=NOT_BLOCKED"
  echo "MB1_DOCKER_HOST_EXTERNAL_WRITERS=NOT_EXCLUDED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$code"
}
trap cleanup EXIT
mkdir -m 0700 "$root/objects" "$root/journal" "$root/control" "$root/snapshot"
docker network create --internal "$network" >/dev/null
made_net=1
docker run -d --name "$db" --network "$network" \
  -e POSTGRES_USER=mb1admin -e POSTGRES_DB=mb1domain \
  -e POSTGRES_PASSWORD=synthetic-only postgres:17-alpine >/dev/null
made_db=1
ready=0
for _ in $(seq 1 45); do
  if docker exec "$db" pg_isready -U mb1admin -d mb1domain >/dev/null 2>&1; then
    ready=1; break
  fi
  sleep 1
done
[ "$ready" = 1 ]
sql() {
  docker exec "$db" psql -X -A -t -v ON_ERROR_STOP=1 -U mb1admin -d "$1" -c "$2"
}
sql mb1domain "CREATE TABLE mb1_domain_sequence (id integer PRIMARY KEY, seq integer NOT NULL);" >/dev/null
sql mb1domain "INSERT INTO mb1_domain_sequence VALUES (1,0);" >/dev/null
sql mb1domain "CREATE ROLE mb1worker LOGIN PASSWORD 'synthetic-only';" >/dev/null
sql mb1domain "GRANT CONNECT ON DATABASE mb1domain TO mb1worker;" >/dev/null
sql mb1domain "GRANT USAGE ON SCHEMA public TO mb1worker;" >/dev/null
sql mb1domain "GRANT SELECT,UPDATE ON mb1_domain_sequence TO mb1worker;" >/dev/null
docker run -d --name "$writer" --network "$network" \
  -e "PGHOST=$db" -e PGUSER=mb1worker -e PGDATABASE=mb1domain \
  -e PGPASSWORD=synthetic-only \
  --mount "type=bind,src=$root/objects,dst=/lab/objects" \
  --mount "type=bind,src=$root/journal,dst=/lab/journal" \
  --mount "type=bind,src=$root/control,dst=/lab/control,readonly" \
  postgres:17-alpine sh -ec '
    i=0
    while [ ! -f /lab/control/STOP ]; do
      i=$((i+1))
      psql -X -q -v ON_ERROR_STOP=1 \
        -c "UPDATE mb1_domain_sequence SET seq=$i WHERE id=1;" >/dev/null
      printf "%s" "$i" > /lab/objects/sequence
      printf "%s" "$i" > /lab/journal/sequence
      sleep 0.15
    done
  ' >/dev/null
made_writer=1
progress=0
for _ in $(seq 1 60); do
  if [ -s "$root/journal/sequence" ]; then
    value="$(cat "$root/journal/sequence")"
    if [ "$value" -ge 3 ] 2>/dev/null; then progress=1; break; fi
  fi
  if [ "$(docker inspect --format '{{.State.Running}}' "$writer")" != true ]; then break; fi
  sleep 0.2
done
if [ "$progress" != 1 ]; then
  echo "MB1_DOMAIN_WRITER_SETUP=FAILED" >&2; exit 1
fi
echo "MB1_DOMAIN_REAL_SQL_AND_FILE_WRITER=OK"
touch "$root/control/STOP"
drained=0
for _ in $(seq 1 60); do
  if [ "$(docker inspect --format '{{.State.Running}}' "$writer")" = false ]; then
    drained=1; break
  fi
  sleep 0.2
done
if [ "$drained" != 1 ]; then
  echo "MB1_DOMAIN_DRAIN_TIMEOUT=FAILED" >&2; exit 1
fi
if [ "$(docker inspect --format '{{.State.ExitCode}}' "$writer")" != 0 ]; then
  echo "MB1_DOMAIN_WRITER_EXIT_ERROR=FAILED" >&2; exit 1
fi
if docker exec "$writer" sh -c 'exit 0' >/dev/null 2>&1; then
  echo "MB1_DOMAIN_WRITER_EXEC_BYPASS=FAILED" >&2; exit 1
fi
echo "MB1_DOMAIN_WRITER_PROCESS_DRAINED=OK"
db_value="$(sql mb1domain 'SELECT seq FROM mb1_domain_sequence WHERE id=1;')"
object_value="$(cat "$root/objects/sequence")"
journal_value="$(cat "$root/journal/sequence")"
if [ "$db_value" != "$object_value" ] || [ "$db_value" != "$journal_value" ]; then
  echo "MB1_DOMAIN_QUIESCENCE_DATA_MISMATCH=FAILED" >&2; exit 1
fi
echo "MB1_DOMAIN_QUIESCENCE_CROSS_RESOURCE=OK"
if docker run --rm --network none \
  --mount "type=bind,src=$root/objects,dst=/lab/objects,readonly" \
  postgres:17-alpine sh -ec 'printf bypass > /lab/objects/sequence' \
  >/dev/null 2>&1; then
  echo "MB1_DOMAIN_READONLY_MOUNT_BYPASSED=FAILED" >&2; exit 1
fi
if [ "$(cat "$root/objects/sequence")" != "$object_value" ]; then
  echo "MB1_DOMAIN_RO_MOUNT_MODIFIED_FILE=FAILED" >&2; exit 1
fi
echo "MB1_DOMAIN_READONLY_MOUNT_DENIES_WRITE=OK"
docker exec "$db" pg_dump -Fc -U mb1admin -d mb1domain > "$root/snapshot/database.dump"
cp -a "$root/objects" "$root/snapshot/objects"
cp -a "$root/journal" "$root/snapshot/journal"
docker exec "$db" createdb -U mb1admin mb1domainrestore
docker exec -i "$db" pg_restore -U mb1admin -d mb1domainrestore --no-owner \
  < "$root/snapshot/database.dump"
restore_seq="$(sql mb1domainrestore 'SELECT seq FROM mb1_domain_sequence WHERE id=1;')"
[ "$restore_seq" = "$db_value" ]
[ "$(cat "$root/snapshot/objects/sequence")" = "$restore_seq" ]
[ "$(cat "$root/snapshot/journal/sequence")" = "$restore_seq" ]
echo "MB1_DOMAIN_QUIESCED_SNAPSHOT_RESTORE=OK"
echo "MB1_DOMAIN_OPERATED_ONLY_TEMP_RESOURCES=OK"
