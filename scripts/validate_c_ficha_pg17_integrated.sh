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
  rm -f -- "$LOG.plan"
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
 -e DJANGO_SECRET_KEY=synthetic-c-ficha-isolated-test-key-2026-long \
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
 -e DJANGO_SECRET_KEY=synthetic-c-ficha-isolated-test-key-2026-long \
 -e DJANGO_ALLOWED_HOSTS=localhost,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=c_ficha \
 -e POSTGRES_USER=c_ficha -e POSTGRES_PASSWORD=synthetic-c-ficha-only \
 "$IMAGE" python manage.py)
PHASE=BASELINE_0018
"${DCMD[@]}" migrate reminders 0018_draft_reasons --noinput >>"$LOG" 2>&1
"${DCMD[@]}" shell -c 'from django.db.migrations.recorder import MigrationRecorder; from django.db import connection; x=MigrationRecorder(connection).applied_migrations(); assert ("reminders","0018_draft_reasons") in x; assert not any(app=="reminders" and name.startswith(tuple(f"{i:04d}_" for i in range(19,28))) for app,name in x)' >>"$LOG" 2>&1
echo "C_FICHA_BASELINE_0018_NO_MFA=OK"
PHASE=MIGRATION_PLAN
"${DCMD[@]}" migrate reminders 0027_renewal_attachment_metadata --plan > "$LOG.plan" 2>&1
grep -Fq "0019_user_mfa_state" "$LOG.plan"
grep -Fq "0026_user_mfa_pending_administrative_case" "$LOG.plan"
grep -Fq "0027_renewal_attachment_metadata" "$LOG.plan"
rm -f "$LOG.plan"
echo "C_FICHA_0027_REQUIRES_MFA_MIGRATIONS=CONFIRMED"
echo "C_FICHA_0027_LIVE_MIGRATION=BLOCKED"
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
 reminders.test_attachment_api reminders.test_attachment_scan_attestation \
 reminders.test_attachment_quarantine_intake reminders.test_attachment_orphan_audit \
 reminders.test_attachment_orphan_snapshot reminders.test_attachment_scanner_worker \
 reminders.test_attachment_release_boundaries \
 --noinput >>"$LOG" 2>&1
echo "C_FICHA_PG17_INTEGRATED_TESTS=OK"
PHASE=FLUTTER
sudo docker run --rm \
 -v "$PWD/clients/flutter:/work" -w /work \
 ghcr.io/cirruslabs/flutter:stable \
 sh -ec "flutter pub get && flutter analyze && flutter test && flutter build web --release --pwa-strategy=none" >>"$LOG" 2>&1
echo "C_FICHA_FLUTTER_ANALYZE_TEST_BUILD=OK"
echo "C_FICHA_PUBLIC_UPLOAD_DOWNLOAD=DISABLED"
echo "C_FICHA_LIVE_MIGRATION_0027=NOT_AUTHORIZED"
