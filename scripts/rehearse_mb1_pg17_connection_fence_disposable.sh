#!/usr/bin/env bash
# MB1 M1-04: PostgreSQL connection fence rehearsal, isolated DB only.
set -Eeuo pipefail
umask 077
cd "$(dirname "$0")/.."
test "$(git branch --show-current)" = feature/c-ficha-independent-attachments
project="mb1_fence_$$_$RANDOM"
db="${project}_pg"
created=0
cleanup() {
  rc=$?; trap - EXIT
  if [ "$created" = 1 ]; then docker rm -f "$db" >/dev/null 2>&1 || rc=1; fi
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
# Only current session? Existing sessions continue despite REVOKE.
# Block ordinary logins by role-level NOLOGIN; the superuser remains a bypass.
sql "ALTER ROLE mb1writer NOLOGIN;" >/dev/null
if docker exec "$db" sh -ec 'PGPASSWORD=synthetic-only psql -h 127.0.0.1 -X -A -t -U mb1writer -d mb1fence -c "SELECT 1"' >/dev/null 2>&1; then
 echo "MB1_PG17_NEW_WRITER_DENIAL=FAILED" >&2; exit 1
fi
echo "MB1_PG17_NEW_WRITER_DENIAL=OK"
# Deliberately avoid claiming existing writers drained, because no session is held.
echo "MB1_PG17_EXISTING_WRITER_DRAIN=NOT_VERIFIED"
# Superuser retains authority and local privileged callers can bypass.
if [ "$(sql 'SELECT 1')" != 1 ]; then exit 1; fi
echo "MB1_PG17_ADMIN_BYPASS_CONFIRMED=OK"
