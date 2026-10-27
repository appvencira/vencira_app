#!/usr/bin/env bash
# MFA: O5 restore to ephemeral PG17 then migrate clone only.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=PRECONDITIONS
LOG="$(mktemp /tmp/vencira-mfa-rehearsal.XXXXXXXX.log)"
NET="vencira_mfa_net_$$"; DB="vencira_mfa_db_$$"
IMAGE="vencira-mfa-test:$(git rev-parse --short=12 HEAD)"
NET_CREATED=0; DB_CREATED=0
finish() {
 rc=$?; trap - EXIT
 if [ "$DB_CREATED" = 1 ]; then docker rm -f "$DB" >>"$LOG" 2>&1 || true; fi
 if [ "$NET_CREATED" = 1 ]; then docker network rm "$NET" >>"$LOG" 2>&1 || true; fi
 if [ "$rc" != 0 ]; then echo "FASE_FALLIDA=$PHASE"; fi
 echo "RESULTADO_CLON_MFA=$rc"; echo "BD_PERSISTENTE_INTACTA=1"; echo "LOG_PRIVADO=$LOG"; echo "CONSOLA_ABIERTA"; exit "$rc"
}
trap finish EXIT
test "$(id -u)" -eq 0
test "${MFA_O5_CLONE_CONFIRM:-}" = RESTORE_ONLY_EPHEMERAL_CLONE
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
exec 8>/run/lock/vencira-o5-backup.lock; flock -n 8
LIVE=vencira_localcheck-db-1
LIVE_ID="$(docker inspect "$LIVE" --format "{{.Id}}")"
test "$(docker inspect "$LIVE" --format "{{index .Config.Labels \"com.docker.compose.project\"}}")" = vencira_localcheck
test "$(docker inspect "$LIVE" --format "{{.State.Health.Status}}")" = healthy
live_sql() { docker exec "$LIVE" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "$1"' sh "$1"; }
test "$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0018_draft_reasons
LIVE_COUNT="$(live_sql "SELECT COUNT(*) FROM django_migrations;")"
echo "LIVE_0018_READONLY=OK"
PHASE=O5
DIR=/etc/vencira-backup
test -d "$DIR" && test ! -L "$DIR" && test "$(stat -c %u:%a "$DIR")" = 0:700
for f in config.env restic-password rclone.conf; do test -f "$DIR/$f" && test ! -L "$DIR/$f" && test "$(stat -c %u:%a "$DIR/$f")" = 0:600; done
. "$DIR/config.env"
test "$RESTIC_REPOSITORY" = rclone:vencira_google:VENCIRA-Backups/PostgreSQL
test "$RESTIC_PASSWORD_FILE" = "$DIR/restic-password"
test "$RCLONE_CONFIG" = "$DIR/rclone.conf"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE RCLONE_CONFIG
restic snapshots --quiet --tag vencira-postgresql >>"$LOG" 2>&1
echo "O5_SNAPSHOT_READABLE=OK"
PHASE=BUILD; docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
PHASE=CLONE
docker network create --internal "$NET" >>"$LOG" 2>&1; NET_CREATED=1
docker run -d --name "$DB" --network "$NET" --network-alias mfa-clone-db -e POSTGRES_DB=mfa_clone -e POSTGRES_USER=mfa_clone -e POSTGRES_PASSWORD=ephemeral-clone-only postgres:17-alpine >>"$LOG" 2>&1; DB_CREATED=1
ready=0; for i in $(seq 1 40); do if docker exec "$DB" pg_isready -U mfa_clone -d mfa_clone >>"$LOG" 2>&1; then ready=1; break; fi; sleep 2; done; test "$ready" = 1
echo "PG17_TEMPORAL=OK"
PHASE=RESTORE
restic dump --tag vencira-postgresql latest vencira-postgres.dump 2>>"$LOG" | docker exec -i "$DB" pg_restore --clean --if-exists --no-owner --no-privileges --exit-on-error -U mfa_clone -d mfa_clone >>"$LOG" 2>&1
clone_sql() { docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U mfa_clone -d mfa_clone -Atqc "$1"; }
test "$(clone_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0018_draft_reasons
echo "O5_RESTORE_0018=OK"
PHASE=MFA_MIGRATIONS
docker run --rm --network "$NET" -e VENCIRA_ENV=test -e DJANGO_DEBUG=0 -e DJANGO_SECRET_KEY=temporary-mfa-clone-django-secret-2026 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 -e POSTGRES_HOST=mfa-clone-db -e POSTGRES_DB=mfa_clone -e POSTGRES_USER=mfa_clone -e POSTGRES_PASSWORD=ephemeral-clone-only "$IMAGE" python manage.py migrate reminders 0021_mfa_prepared_at --noinput >>"$LOG" 2>&1
test "$(clone_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0021_mfa_prepared_at
test "$(clone_sql "SELECT to_regclass('public.reminders_usermfastate') IS NOT NULL;")" = t
test "$(clone_sql "SELECT to_regclass('public.reminders_usermfarecoverycode') IS NOT NULL;")" = t
echo "MFA_MIGRATION_CLONE=OK"
PHASE=LIVE_POST
test "$LIVE_ID" = "$(docker inspect "$LIVE" --format "{{.Id}}")"
test "$LIVE_COUNT" = "$(live_sql "SELECT COUNT(*) FROM django_migrations;")"
test "$(live_sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1;")" = 0018_draft_reasons
echo "LIVE_UNCHANGED=OK"
