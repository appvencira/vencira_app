#!/usr/bin/env bash
# Operational Django login/MFA REGRESSION in a disposable PostgreSQL 17 lab.
# No public ports, no credentials from DEV, no live migrations and no deployment.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
command -v docker >/dev/null
command -v openssl >/dev/null
if [[ "$(id -u)" != "0" ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == "0" ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A BEFORE
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service")" = vencira_localcheck || exit 3
  test "$(D inspect -f '{{.State.Health.Status}}' "$service")" = healthy || exit 3
  BEFORE[$service]="$(D inspect -f '{{.Id}}:{{.Image}}' "$service")"
done
network="vencira-login-mfa-lab-$$"
db="vencira-login-mfa-pg17-$$"
image="vencira-login-mfa-lab:$$"
tmp="$(mktemp -d /tmp/vencira-login-mfa-lab.XXXXXXXX)"
chmod 700 "$tmp"
started_network=0
built_image=0
cleanup() {
  local status=$?
  trap - EXIT
  D rm -f "$db" >/dev/null 2>&1 || true
  if [[ "$started_network" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$built_image" == 1 ]]; then D image rm "$image" >/dev/null 2>&1 || true; fi
  if [[ -d "$tmp" && "$tmp" == /tmp/vencira-login-mfa-lab.* ]]; then rm -f "$tmp/env"; rmdir "$tmp" || true; fi
  local stable=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" != "${BEFORE[$service]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "LOGIN_MFA_LIVE_CONTAINERS_UNCHANGED=OK"; else
    echo "LOGIN_MFA_LIVE_CONTAINERS_UNCHANGED=FAIL"; status=9
  fi
  echo "LOGIN_MFA_DEPLOY_EXECUTED=NO"
  echo "LOGIN_MFA_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "LOGIN_MFA_PG17_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

# Only a new, ephemeral image. Never tag the operational api image.
D build -q -t "$image" ./backend >/dev/null
built_image=1
echo "LOGIN_MFA_DISPOSABLE_IMAGE_BUILT=OK"
pass="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=loginlab
POSTGRES_USER=loginlab
POSTGRES_PASSWORD=$pass
POSTGRES_HOST=$db
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_NATIVE_SERVICE_CANDIDATE=0
VENCIRA_NATIVE_SESSION_LAB=0
EOF
chmod 600 "$tmp/env"
D network create --internal "$network" >/dev/null
started_network=1
test "$(D network inspect -f '{{.Internal}}' "$network")" = "true" || exit 4
echo "LOGIN_MFA_INTERNAL_NETWORK=OK"
D run --rm -d --name "$db" --network "$network" \
  --tmpfs /var/lib/postgresql/data:rw,size=384m \
  -e POSTGRES_DB=loginlab -e POSTGRES_USER=loginlab -e POSTGRES_PASSWORD="$pass" \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U loginlab -d loginlab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" = YES || { echo "LOGIN_MFA_PG17_READY=FAIL"; exit 5; }
echo "LOGIN_MFA_PG17_READY=YES"
django() { D run --rm --network "$network" --env-file "$tmp/env" "$image" python manage.py "$@"; }
django check >/dev/null
echo "LOGIN_MFA_DJANGO_CHECK=OK"
# This applies MFA and historic attachment migrations ONLY to the disposable lab DB.
django migrate --noinput >/dev/null
echo "LOGIN_MFA_DISPOSABLE_FULL_MIGRATIONS=OK"
django shell -c '
from django.db.migrations.recorder import MigrationRecorder
applied=set(MigrationRecorder.Migration.objects.values_list("app","name"))
required={("reminders","0018_draft_reasons"),("reminders","0019_user_mfa_state"),("reminders","0026_user_mfa_pending_administrative_case"),("reminders","0027_renewal_attachment_metadata")}
assert required <= applied, sorted(required-applied)
print("LOGIN_MFA_ISOLATED_MIGRATION_GRAPH=PASS")
' | grep -Fx "LOGIN_MFA_ISOLATED_MIGRATION_GRAPH=PASS"
# Test runner creates its own ephemeral test DB inside this disposable PG17.
# These cases exercise the actual /accounts/login/, /accounts/mfa/, middleware,
# account lockouts and session gating; they are not the test-only HTTP login.
django test reminders.test_login_security reminders.test_mfa_login --verbosity 1
echo "LOGIN_MFA_OPERATIONAL_AUTH_REGRESSION=PASS"
echo "LOGIN_MFA_GATE_RESULT=PASS"
