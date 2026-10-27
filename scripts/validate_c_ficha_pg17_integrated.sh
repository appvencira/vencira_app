#!/usr/bin/env bash
# C-FICHA: isolated PG17 only; never touches running VENCIRA services.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=PREFLIGHT
LOG="$(mktemp /tmp/vencira-c-ficha-pg17.XXXXXXXX.log)"
NET="vencira_c_ficha_net_$$"
DB="vencira_c_ficha_db_$$"
NET_OK=0; DB_OK=0
cleanup() {
  local rc=$? clean=0
  trap - EXIT
  if [ "$DB_OK" = 1 ]; then sudo docker rm -f "$DB" >>"$LOG" 2>&1 || clean=1; fi
  if [ "$NET_OK" = 1 ]; then sudo docker network rm "$NET" >>"$LOG" 2>&1 || clean=1; fi
  if [ "$clean" != 0 ]; then echo "CLEANUP=FAILED"; rc=1; else echo "CLEANUP=OK"; fi
  if [ "$rc" != 0 ]; then echo "FAILED_PHASE=$PHASE"; tail -n 30 "$LOG"; fi
  echo "C_FICHA_PG17_GATE_RESULT=$rc"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "LOG_LOCAL=$LOG"
  exit "$rc"
}
trap cleanup EXIT
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
echo "COMMIT=$(git rev-parse HEAD)"
IMAGE="vencira-c-ficha-test:$(git rev-parse --short=12 HEAD)"
PHASE=BUILD
sudo docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
PHASE=SQLITE_MIGRATION_CHECK
sudo docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_SECRET_KEY=synthetic-c-ficha-only-key-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver "$IMAGE" \
 python manage.py makemigrations --check --dry-run >>"$LOG" 2>&1
echo "C_FICHA_MIGRATIONS_MATCH_MODELS=OK"
PHASE=PG17
sudo docker network create --internal "$NET" >>"$LOG" 2>&1; NET_OK=1
sudo docker run -d --name "$DB" --network "$NET" \
 -e POSTGRES_DB=c_ficha -e POSTGRES_USER=c_ficha \
 -e POSTGRES_PASSWORD=synthetic-c-ficha-only postgres:17-alpine >>"$LOG" 2>&1
DB_OK=1
ready=0
for _ in $(seq 1 40); do
 if sudo docker exec "$DB" pg_isready -U c_ficha -d c_ficha >>"$LOG" 2>&1; then ready=1; break; fi
 sleep 2
done
test "$ready" = 1
echo "C_FICHA_PG17_EPHEMERAL=OK"
DCMD=(sudo docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
 -e DJANGO_SECRET_KEY=synthetic-c-ficha-only-key-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=c_ficha \
 -e POSTGRES_USER=c_ficha -e POSTGRES_PASSWORD=synthetic-c-ficha-only \
 "$IMAGE" python manage.py)
PHASE=MIGRATION
"${DCMD[@]}" migrate reminders 0027_renewal_attachment_metadata --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c 'from django.db.migrations.recorder import MigrationRecorder; from django.db import connection; x=MigrationRecorder(connection).applied_migrations(); assert ("reminders","0026_user_mfa_pending_administrative_case") in x; assert ("reminders","0027_renewal_attachment_metadata") in x' >>"$LOG" 2>&1
echo "C_FICHA_SCHEMA_0027_WITH_MFA_DEPENDENCY=OK"
PHASE=INTEGRATED_TESTS
"${DCMD[@]}" test \
 reminders.test_attachment_validation reminders.test_attachment_metadata \
 reminders.test_attachment_private_store reminders.test_attachment_gate \
 reminders.test_attachment_content_inspection reminders.test_attachment_scan_contract \
 reminders.test_attachment_clamav_adapter reminders.test_attachment_scan_pipeline \
 --noinput >>"$LOG" 2>&1
echo "C_FICHA_PG17_INTEGRATED_TESTS=OK"
echo "C_FICHA_PUBLIC_UPLOAD_DOWNLOAD=DISABLED"
echo "C_FICHA_LIVE_MIGRATION_0027=NOT_AUTHORIZED"
