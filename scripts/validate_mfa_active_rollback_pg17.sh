#!/usr/bin/env bash
# A rehearsal of the rollback DECISION, not a destructive schema downgrade.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
test "$(git branch --show-current)" = integration/local-e2e-prep
test -z "$(git diff --name-only)"
test -z "$(git diff --cached --name-only)"
LOG="$(mktemp /tmp/vencira-mfa-active-rollback.XXXXXXXX.log)"
NET="vencira_mfa_active_net_$$"
DB="vencira_mfa_active_db_$$"
IMAGE="vencira-mfa-active:$(git rev-parse --short=12 HEAD)"
net_created=0; db_created=0
cleanup(){
 rc=$?; trap - EXIT
 if [ "$db_created" = 1 ]; then sudo docker rm -f "$DB" >>"$LOG" 2>&1 || rc=1; fi
 if [ "$net_created" = 1 ]; then sudo docker network rm "$NET" >>"$LOG" 2>&1 || rc=1; fi
 echo "MFA_ACTIVE_ROLLBACK_RESULT=$rc"
 echo "MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO"
 echo "MFA_RELEASE_AUTHORIZED=NO"
 echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
 echo "LOG_LOCAL=$LOG"
 if [ "$rc" -ne 0 ]; then tail -n 35 "$LOG"; fi
 exit "$rc"
}
trap cleanup EXIT
sudo docker build -t "$IMAGE" ./backend >>"$LOG" 2>&1
sudo docker network create --internal "$NET" >>"$LOG" 2>&1; net_created=1
sudo docker run -d --name "$DB" --network "$NET" \
  -e POSTGRES_DB=active_test -e POSTGRES_USER=active_test \
  -e POSTGRES_PASSWORD=synthetic-only postgres:17-alpine >>"$LOG" 2>&1
db_created=1
ready=0
for i in $(seq 1 40); do
 if sudo docker exec "$DB" pg_isready -U active_test -d active_test >>"$LOG" 2>&1; then ready=1; break; fi
 sleep 2
done
test "$ready" -eq 1
echo "MFA_ACTIVE_PG17_EPHEMERAL=OK"
dcmd=(sudo docker run --rm --network "$NET" \
 -e VENCIRA_ENV=test -e VENCIRA_DB_ENGINE=postgresql \
 -e DJANGO_DEBUG=0 -e DJANGO_SECRET_KEY=synthetic-only-django-secret-for-mfa-rollback-2026 \
 -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
 -e POSTGRES_HOST="$DB" -e POSTGRES_DB=active_test -e POSTGRES_USER=active_test \
 -e POSTGRES_PASSWORD=synthetic-only "$IMAGE" python manage.py)
"${dcmd[@]}" migrate reminders 0026_user_mfa_pending_administrative_case --noinput >>"$LOG" 2>&1
echo "MFA_ACTIVE_SCHEMA_0026=OK"
"${dcmd[@]}" shell -c '
from django.contrib.auth import get_user_model
from django.utils import timezone
from reminders.models import UserMfaState
user=get_user_model().objects.create_user(username="rollback_synthetic",password="SyntheticOnlyPassword-2026!",last_login=timezone.now())
UserMfaState.objects.create(user=user,enabled=True,encrypted_totp_secret="synthetic-never-real")
' >>"$LOG" 2>&1
echo "MFA_SYNTHETIC_ACTIVE_ACCOUNT=OK"
set +e
"${dcmd[@]}" mfa_rollback_guard --candidate-lacks-mfa >>"$LOG" 2>&1
denied_rc=$?
set -e
test "$denied_rc" -ne 0
grep -Fq 'MFA_ROLLBACK_GUARD=MFA_DOWNGRADE_FORBIDDEN' "$LOG"
echo "MFA_ACTIVE_DOWNGRADE_REJECTED=OK"
"${dcmd[@]}" mfa_rollback_guard --candidate-enforces-mfa >>"$LOG" 2>&1
grep -Fq 'MFA_ROLLBACK_PRECHECK=OK' "$LOG"
echo "MFA_ENFORCING_CANDIDATE_PRECHECK=OK"
"${dcmd[@]}" test reminders.test_mfa_session_revocation reminders.test_mfa_rollback_guard --noinput >>"$LOG" 2>&1
echo "MFA_SESSION_ENFORCEMENT_TESTS=OK"
echo "MFA_DESTRUCTIVE_SCHEMA_DOWNGRADE=NOT_RUN"
