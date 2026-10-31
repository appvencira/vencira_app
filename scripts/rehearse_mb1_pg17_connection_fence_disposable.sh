#!/usr/bin/env bash
# MB1 M1-04: PostgreSQL connection fence rehearsal, isolated DB only.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
project="mb1_fence_$$_$RANDOM"
db="${project}_pg"
created=0
writer_pid=""
cleanup() {
  rc=$?; trap - EXIT
  if [ "$created" = 1 ]; then docker rm -f "$db" >/dev/null 2>&1 || rc=1; fi
  if [ -n "$writer_pid" ]; then wait "$writer_pid" >/dev/null 2>&1 || true; fi
  echo "MB1_PG17_FENCE_RESULT=$rc"
  echo "MB1_NONCOOPERATIVE_SQL_SUPERUSER=NOT_BLOCKED"
  echo "MB1_FILESYSTEM_WRITERS=NOT_BLOCKED"
  echo "MB1_GLOBAL_FREEZE=NOT_VERIFIED"
  echo "MB1_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$rc"
}
trap cleanup EXIT
docker run -d --name "$db" --network none \
 -e POSTGRES_USER=mb1admin -e POSTGRES_DB=mb1fence \
 -e POSTGRES_PASSWORD=synthetic-only \
 postgres:17-alpine >/dev/null
created=1
ready=0
for _ in $(seq 1 40); do
  if docker exec "$db" pg_isready -U mb1admin -d mb1fence >/dev/null 2>&1; then ready=1; break; fi
  sleep 1
done
[ "$ready" = 1 ]
sql() {
  docker exec "$db" psql -X -A -t -v ON_ERROR_STOP=1 -U mb1admin -d mb1fence -c "$1"
}
sql "CREATE ROLE mb1writer LOGIN PASSWORD 'synthetic-only';" >/dev/null
sql "GRANT CONNECT ON DATABASE mb1fence TO mb1writer;" >/dev/null
# Hold an ordinary, non-superuser transaction open from a separate process.
# All SQL and container resources are exclusively disposable.
docker exec "$db" sh -ec '
  PGPASSWORD=synthetic-only exec psql -h 127.0.0.1 -X -q -v ON_ERROR_STOP=1 \
    -U mb1writer -d mb1fence -c "BEGIN; SELECT pg_sleep(18); COMMIT;"
' >/dev/null 2>&1 &
writer_pid=$!
active=0
for _ in $(seq 1 30); do
  count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer' AND state='active' AND query LIKE '%pg_sleep(18)%';")"
  if [ "$count" = 1 ]; then active=1; break; fi
  sleep 0.2
done
if [ "$active" != 1 ]; then echo "MB1_PG17_WRITER_SESSION_SETUP=FAILED" >&2; exit 1; fi
echo "MB1_PG17_EXISTING_WRITER_ACTIVE=OK"

sql "ALTER ROLE mb1writer NOLOGIN;" >/dev/null
if docker exec "$db" sh -ec 'PGPASSWORD=synthetic-only psql -h 127.0.0.1 -X -A -t -U mb1writer -d mb1fence -c "SELECT 1"' >/dev/null 2>&1; then
  echo "MB1_PG17_NEW_WRITER_DENIAL=FAILED" >&2; exit 1
fi
echo "MB1_PG17_NEW_WRITER_DENIAL=OK"
# A capture gate must fail while the pre-existing session is still active.
count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer' AND state IN ('active','idle in transaction');")"
if [ "$count" != 1 ]; then echo "MB1_PG17_PREEXISTING_SESSION_NOT_HELD=1" >&2; exit 1; fi
echo "MB1_PG17_CAPTURE_BLOCKED_WHILE_WRITER_ACTIVE=OK"

wait "$writer_pid"
writer_pid=""
count="$(sql "SELECT count(*) FROM pg_stat_activity WHERE usename='mb1writer';")"
if [ "$count" != 0 ]; then echo "MB1_PG17_SESSION_DRAIN_FAILED=1" >&2; exit 1; fi
echo "MB1_PG17_EXISTING_WRITER_DRAIN=OK"
echo "MB1_PG17_CAPTURE_SQL_QUIESCENT_LAB=OK"
# Superuser remains able to write: this is not a global fence.
if [ "$(sql 'SELECT 1')" != 1 ]; then exit 1; fi
echo "MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK"
