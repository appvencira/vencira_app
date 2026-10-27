#!/usr/bin/env bash
# Synthetic PG17 only. Does NOT prove safe rollback once MFA users exist.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
LOG="$(mktemp /tmp/vencira-mfa-schema-roundtrip.XXXXXXXX.log)"
NET="vencira_mfa_roundtrip_net_$$"
DB="vencira_mfa_roundtrip_db_$$"
IMAGE="vencira-mfa-roundtrip:$(git rev-parse --short=12 HEAD)"
net_created=0; db_created=0
finish(){
  rc=$?; trap - EXIT
  if [ "$db_created" = 1 ]; then sudo docker rm -f "$DB" >>"$LOG" 2>&1 || rc=1; fi
  if [ "$net_created" = 1 ]; then sudo docker network rm "$NET" >>"$LOG" 2>&1 || rc=1; fi
  echo "MFA_SCHEMA_ROUNDTRIP_RESULT=$rc"
  echo "MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "LOG_LOCAL=$LOG"
  exit "$rc"
}
trap finish EXIT
sudo docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
sudo docker network create --internal "$NET" >>"$LOG" 2>&1; net_created=1
sudo docker run -d --name "$DB" --network "$NET" \
  -e POSTGRES_DB=roundtrip -e POSTGRES_USER=roundtrip \
  -e POSTGRES_PASSWORD=synthetic-only postgres:17-alpine >>"$LOG" 2>&1
db_created=1
ready=0
for i in $(seq 1 40); do
  if sudo docker exec "$DB" pg_isready -U roundtrip -d roundtrip >>"$LOG" 2>&1; then ready=1; break; fi
  sleep 2
done
test "$ready" -eq 1
echo "MFA_PG17_EPHEMERAL=OK"
dcmd=(sudo docker run --rm --network "$NET" \
  -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
  -e DJANGO_DEBUG=0 -e DJANGO_SECRET_KEY=synthetic-mfa-roundtrip-django-secret-2026-ephemeral-only \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  -e POSTGRES_HOST="$DB" -e POSTGRES_DB=roundtrip \
  -e POSTGRES_USER=roundtrip -e POSTGRES_PASSWORD=synthetic-only \
  "$IMAGE" python manage.py)
sql(){
  sudo docker exec "$DB" psql -X -v ON_ERROR_STOP=1 -U roundtrip -d roundtrip -Atqc "$1"
}
# Start from the historical non-MFA schema in the isolated empty database.
"${dcmd[@]}" migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1")" = 0018_draft_reasons
test "$(sql "SELECT to_regclass('public.reminders_usermfastate') IS NULL")" = t
echo "MFA_SCHEMA_0018_BASELINE=OK"
"${dcmd[@]}" migrate reminders 0026_user_mfa_pending_administrative_case --noinput >>"$LOG" 2>&1
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1")" = 0026_user_mfa_pending_administrative_case
test "$(sql "SELECT to_regclass('public.reminders_usermfastate') IS NOT NULL")" = t
test "$(sql "SELECT to_regclass('public.reminders_mfaadministrativerecoverycase') IS NOT NULL")" = t
echo "MFA_SCHEMA_UP_0026=OK"
# Empty-clone schema reversal is not evidence that live-user MFA rollback is safe.
"${dcmd[@]}" migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1")" = 0018_draft_reasons
test "$(sql "SELECT to_regclass('public.reminders_usermfastate') IS NULL")" = t
echo "MFA_SCHEMA_DOWN_0018_EMPTY_ONLY=OK"
"${dcmd[@]}" migrate reminders 0026_user_mfa_pending_administrative_case --noinput >>"$LOG" 2>&1
test "$(sql "SELECT name FROM django_migrations WHERE app='reminders' ORDER BY name DESC LIMIT 1")" = 0026_user_mfa_pending_administrative_case
echo "MFA_SCHEMA_REAPPLY_0026=OK"
echo "MFA_SCHEMA_LIVE_USER_ROLLBACK=NOT_TESTED"
