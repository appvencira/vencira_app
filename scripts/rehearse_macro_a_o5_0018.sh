#!/usr/bin/env bash
# VENCIRA macro A: recuperar O5 en PG17 efimero y ensayar migraciones 0017/0018.
# Nunca escribir en la base viva ni registrar secretos.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=IDENTITY
LOG="$(mktemp /tmp/vencira-macro-a-restore.XXXXXXXX.log)"
NET="vencira_a_restore_net_$$"
DB="vencira_a_restore_db_$$"
IMAGE="vencira-a-rehearsal:$(git rev-parse --short=12 HEAD)"
NET_CREATED=0
DB_CREATED=0
finish() {
  rc=$?
  trap - EXIT
  if [ "$DB_CREATED" -eq 1 ]; then docker rm -f "$DB" >>"$LOG" 2>&1 || true; fi
  if [ "$NET_CREATED" -eq 1 ]; then docker network rm "$NET" >>"$LOG" 2>&1 || true; fi
  if [ "$rc" -ne 0 ]; then
    echo "FASE_FALLIDA=$PHASE"
    echo "LOG_LOCAL=$LOG"
  fi
  echo "RESULTADO_GLOBAL=$rc"
  echo "BASE_VIVA_NO_MIGRADA=1"
  echo "SIN_DUMP_DESCIFRADO_EN_DISCO=1"
  exit "$rc"
}
trap finish EXIT
test "$(id -u)" -eq 0
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
exec 8>/run/lock/vencira-o5-backup.lock
flock -n 8
LIVE=vencira_localcheck-db-1
LIVE_ID="$(docker inspect "$LIVE" --format '{{.Id}}')"
test "$(docker inspect "$LIVE" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
test "$(docker inspect "$LIVE" --format '{{.State.Health.Status}}')" = healthy
live_sql() {
  docker exec "$LIVE" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
test "$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0016_renewal_control_responses
LIVE_COUNT="$(live_sql 'SELECT COUNT(*) FROM django_migrations;')"
echo "DEV_0016_PRE=OK"
PHASE=O5_CONFIG
DIR=/etc/vencira-backup
test -d "$DIR" && test ! -L "$DIR" && test "$(stat -c %u:%a "$DIR")" = 0:700
for file in config.env restic-password rclone.conf; do
  test -f "$DIR/$file" && test ! -L "$DIR/$file" && test "$(stat -c %u:%a "$DIR/$file")" = 0:600
done
. "$DIR/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = "$DIR/restic-password"
test "$RCLONE_CONFIG" = "$DIR/rclone.conf"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
restic snapshots --quiet --tag vencira-postgresql >>"$LOG" 2>&1
echo "O5_SNAPSHOTS_ACCESSIBLE=OK"
PHASE=IMAGE
docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
echo "API_IMAGE_BUILT=OK"
PHASE=TEMP_DB
docker network create --internal "$NET" >>"$LOG" 2>&1
NET_CREATED=1
docker run -d --name "$DB" --network "$NET" --network-alias rehearsal-db \
  -e POSTGRES_DB=rehearsal -e POSTGRES_USER=rehearsal \
  -e POSTGRES_PASSWORD=rehearsal-temporary-only postgres:17-alpine >>"$LOG" 2>&1
DB_CREATED=1
ready=0
for i in $(seq 1 40); do
  if docker exec "$DB" pg_isready -U rehearsal -d rehearsal >>"$LOG" 2>&1; then ready=1; break; fi
  sleep 2
done
test "$ready" = 1
echo "PG17_AISLADO=OK"
PHASE=RESTORE
restic dump --tag vencira-postgresql latest vencira-postgres.dump 2>>"$LOG" |
  docker exec -i "$DB" pg_restore --clean --if-exists --no-owner --no-privileges --exit-on-error \
    -U rehearsal -d rehearsal >>"$LOG" 2>&1
before="$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U rehearsal -d rehearsal -Atqc \
  "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
echo "CLON_SCHEMA_RESTORED=$before"
test "$before" = 0016_renewal_control_responses
echo "O5_RESTORE_0016=OK"
PHASE=CLONE_MIGRATION
docker run --rm --network "$NET" \
  -e VENCIRA_ENV=development -e DJANGO_DEBUG=0 \
  -e DJANGO_SECRET_KEY=rehearsal-only-not-production-secret \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  -e POSTGRES_HOST=rehearsal-db -e POSTGRES_PORT=5432 \
  -e POSTGRES_DB=rehearsal -e POSTGRES_USER=rehearsal \
  -e POSTGRES_PASSWORD=rehearsal-temporary-only \
  "$IMAGE" python manage.py migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
after="$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U rehearsal -d rehearsal -Atqc \
  "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$after" = 0018_draft_reasons
test "$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U rehearsal -d rehearsal -Atqc \
  "SELECT to_regclass('public.reminders_operationalreminder') IS NOT NULL;")" = t
test "$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U rehearsal -d rehearsal -Atqc \
  "SELECT to_regclass('public.reminders_operationalreminderevent') IS NOT NULL;")" = t
echo "CLON_0018_VERIFICADO=OK"
PHASE=LIVE_POST
test "$(docker inspect "$LIVE" --format '{{.Id}}')" = "$LIVE_ID"
test "$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0016_renewal_control_responses
test "$(live_sql 'SELECT COUNT(*) FROM django_migrations;')" = "$LIVE_COUNT"
echo "DEV_0016_INTACTO=OK"
echo "MACRO_A_O5_RESTORE_AND_MIGRATION_REHEARSAL=OK"
