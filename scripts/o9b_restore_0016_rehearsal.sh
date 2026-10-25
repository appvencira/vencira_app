#!/usr/bin/env bash
# O9b: restore latest encrypted PostgreSQL snapshot into disposable PG17,
# migrate only the disposable clone to 0016; NEVER touch live database.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=START
LOG="$(mktemp /tmp/vencira-o9b-clone.XXXXXXXX.log)"
NET="vencira_o9b_net_$$"
DB="vencira_o9b_db_$$"
IMAGE="vencira-o9b-check:$(git rev-parse --short=12 HEAD)"
CREATED_NET=0
CREATED_DB=0
finish() {
 rc=$?
 trap - EXIT
 if [ "$CREATED_DB" -eq 1 ]; then docker rm -f "$DB" >>"$LOG" 2>&1 || true; fi
 if [ "$CREATED_NET" -eq 1 ]; then docker network rm "$NET" >>"$LOG" 2>&1 || true; fi
 if [ "$rc" -ne 0 ]; then
   echo "FASE_FALLIDA=$PHASE"
   echo "=== DIAGNOSTICO ==="
   tail -n 35 "$LOG" || true
 fi
 echo "RESULTADO_GLOBAL=$rc"
 echo "BASE_PERSISTENTE_NO_MIGRADA=1"
 echo "CONTENEDORES_TEMPORALES_ELIMINADOS=1"
 echo "LOG_LOCAL=$LOG"
 echo "CONSOLA_ABIERTA"
 exit "$rc"
}
trap finish EXIT
test "$(id -u)" -eq 0
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
for cmd in docker restic rclone flock; do command -v "$cmd" >/dev/null; done
exec 8>/run/lock/vencira-o5-backup.lock
flock -n 8
PHASE=IDENTITY
LIVE=vencira_localcheck-db-1
ID="$(docker inspect "$LIVE" --format '{{.Id}}')"
test "$(docker inspect "$LIVE" --format '{{index .Config.Labels "com.docker.compose.project"}}')" = vencira_localcheck
test "$(docker inspect "$LIVE" --format '{{.State.Health.Status}}')" = healthy
sql_live() {
 docker exec "$LIVE" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"
}
test "$(sql_live "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0015_renewal_reminder_drafts
BEFORE_COUNT="$(sql_live 'SELECT COUNT(*) FROM django_migrations;')"
echo "LIVE_0015_PRE=OK"
PHASE=O5_CONFIG
DIR=/etc/vencira-backup
test -d "$DIR" && test ! -L "$DIR" && test "$(stat -c %u:%a "$DIR")" = 0:700
for item in config.env restic-password rclone.conf; do
 test -f "$DIR/$item" && test ! -L "$DIR/$item" && test "$(stat -c %u:%a "$DIR/$item")" = 0:600
done
. "$DIR/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = "$DIR/restic-password"
test "$RCLONE_CONFIG" = "$DIR/rclone.conf"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
restic snapshots --quiet --tag vencira-postgresql >>"$LOG" 2>&1
echo "RESTIC_SNAPSHOT_READABLE=OK"
PHASE=BUILD_IMAGE
docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
echo "O9B_IMAGE_BUILT=OK"
PHASE=CLONE_START
docker network create --internal "$NET" >>"$LOG" 2>&1
CREATED_NET=1
docker run -d --name "$DB" --network "$NET" --network-alias o9bdb \
 -e POSTGRES_DB=o9b_clone -e POSTGRES_USER=o9b_clone \
 -e POSTGRES_PASSWORD=o9b-ephemeral-only \
 postgres:17-alpine >>"$LOG" 2>&1
CREATED_DB=1
ready=0
for n in $(seq 1 40); do
 if docker exec "$DB" pg_isready -U o9b_clone -d o9b_clone >>"$LOG" 2>&1; then ready=1; break; fi
 sleep 2
done
test "$ready" -eq 1
echo "PG17_CLONE_ISOLATED=OK"
PHASE=RESTORE
restic dump --tag vencira-postgresql latest vencira-postgres.dump 2>>"$LOG" |
 docker exec -i "$DB" pg_restore --clean --if-exists --no-owner --no-privileges --exit-on-error \
 -U o9b_clone -d o9b_clone >>"$LOG" 2>&1
CLONE_BEFORE="$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U o9b_clone -d o9b_clone -Atqc "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$CLONE_BEFORE" = 0015_renewal_reminder_drafts
echo "RESTIC_RESTORE_0015=OK"
PHASE=CLONE_MIGRATION
docker run --rm --network "$NET" \
 -e VENCIRA_ENV=development -e DJANGO_DEBUG=0 \
 -e DJANGO_SECRET_KEY=o9b-temporary-only-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
 -e POSTGRES_HOST=o9bdb -e POSTGRES_PORT=5432 \
 -e POSTGRES_DB=o9b_clone -e POSTGRES_USER=o9b_clone \
 -e POSTGRES_PASSWORD=o9b-ephemeral-only \
 "$IMAGE" python manage.py migrate reminders 0016_renewal_control_responses --noinput >>"$LOG" 2>&1
CLONE_AFTER="$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U o9b_clone -d o9b_clone -Atqc "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")"
test "$CLONE_AFTER" = 0016_renewal_control_responses
test "$(docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U o9b_clone -d o9b_clone -Atqc "SELECT to_regclass('public.reminders_renewalcontrolresponse') IS NOT NULL;")" = t
echo "MIGRACION_0016_SOLO_CLON=OK"
PHASE=LIVE_POST
test "$ID" = "$(docker inspect "$LIVE" --format '{{.Id}}')"
test "$(sql_live "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0015_renewal_reminder_drafts
test "$(sql_live 'SELECT COUNT(*) FROM django_migrations;')" = "$BEFORE_COUNT"
echo "LIVE_0015_INTACTO=OK"
echo "O9B_RESTAURACION_Y_MIGRACION_AISLADA=OK"
