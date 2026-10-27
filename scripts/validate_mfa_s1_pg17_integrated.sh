#!/usr/bin/env bash
# D1.5 S1: pruebas aisladas de revisión y concurrencia en PostgreSQL 17.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
PHASE=PRECHECK
LOG="$(mktemp /tmp/vencira-s1-pg17.XXXXXXXX.log)"
NET="vencira_s1_pg_net_$$"
DB="vencira_s1_pg_db_$$"
NET_OK=0
DB_OK=0
cleanup() {
 local rc=$? clean=0
 trap - EXIT
 if [ "$DB_OK" = 1 ]; then
   sudo docker rm -f "$DB" >>"$LOG" 2>&1 || clean=1
 fi
 if [ "$NET_OK" = 1 ]; then
   sudo docker network rm "$NET" >>"$LOG" 2>&1 || clean=1
 fi
 if [ "$clean" != 0 ]; then echo "CLEANUP=FAILED"; rc=1; else echo "CLEANUP=OK"; fi
 if [ "$rc" != 0 ]; then echo "FAILED_PHASE=$PHASE"; tail -n 35 "$LOG"; fi
 echo "S1_PG17_GATE_RESULT=$rc"
 echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
 echo "LOG_LOCAL=$LOG"
 echo "CONSOLA_ABIERTA"
 exit "$rc"
}
trap cleanup EXIT
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)"
echo "COMMIT=$(git rev-parse HEAD)"
PHASE=BUILD
IMAGE="vencira-s1-test:$(git rev-parse --short=12 HEAD)"
sudo docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
PHASE=SQLITE_AND_MIGRATION_CHECK
sudo docker run --rm --network none \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=sqlite \
 -e DJANGO_DEBUG=0 -e DJANGO_SECRET_KEY=s1-sqlite-ephemeral-only-key-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
 "$IMAGE" sh -ec 'python manage.py check && python manage.py makemigrations --check --dry-run && python manage.py test reminders.test_mfa_admin_recovery_service reminders.test_mfa_admin_recovery_models reminders.test_mfa_admin_recovery_policy reminders.test_mfa_rollback_guard reminders.test_mfa_admin_recovery_concurrency reminders.test_mfa_session_revocation reminders.test_mfa_recovery_exposure reminders.test_mfa_factor_rotation --noinput' >>"$LOG" 2>&1
echo "S1_SQLITE_SECURITY=OK"
PHASE=PG17
sudo docker network create --internal "$NET" >>"$LOG" 2>&1
NET_OK=1
sudo docker run -d --name "$DB" --network "$NET" \
 -e POSTGRES_DB=s1test -e POSTGRES_USER=s1test \
 -e POSTGRES_PASSWORD=s1-synthetic-only postgres:17-alpine >>"$LOG" 2>&1
DB_OK=1
ready=0
for _ in $(seq 1 40); do
 if sudo docker exec "$DB" pg_isready -U s1test -d s1test >>"$LOG" 2>&1; then ready=1; break; fi
 sleep 2
done
test "$ready" = 1
echo "PG17_EPHEMERAL=OK"
PHASE=TESTS
sudo docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
 -e DJANGO_DEBUG=0 -e DJANGO_SECRET_KEY=s1-postgres-ephemeral-only-key-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=s1test \
 -e POSTGRES_USER=s1test -e POSTGRES_PASSWORD=s1-synthetic-only \
 "$IMAGE" python manage.py test \
 reminders.test_mfa_admin_recovery_service \
 reminders.test_mfa_admin_recovery_models \
 reminders.test_mfa_admin_recovery_policy reminders.test_mfa_rollback_guard \
 reminders.test_mfa_admin_recovery_concurrency reminders.test_mfa_session_revocation reminders.test_mfa_recovery_exposure reminders.test_mfa_factor_rotation \
 --noinput --verbosity 1 >>"$LOG" 2>&1
echo "S1_POSTGRES_REVIEW_AND_RACE=OK"
PHASE=STATIC_RELEASE_GUARD
bash scripts/mfa_s1_release_readonly.sh "$(git rev-parse HEAD)" >>"$LOG" 2>&1
echo "S1_STATIC_CANDIDATE_GUARD=OK"
echo "MFA_RELEASE_AUTHORIZED=NO"
