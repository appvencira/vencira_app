#!/usr/bin/env bash
# Actual /accounts/login/ -> /accounts/mfa/ -> /api/v1/me/ over real HTTPS.
# Full migrations ONLY in disposable PG17; do not touch DEV database/services.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for program in docker openssl; do command -v "$program" >/dev/null || exit 2; done
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A BEFORE
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service")" = vencira_localcheck || exit 3
  test "$(D inspect -f '{{.State.Health.Status}}' "$service")" = healthy || exit 3
  BEFORE[$service]="$(D inspect -f '{{.Id}}:{{.Image}}' "$service")"
done
TMP="$(mktemp -d /tmp/vencira-real-login-https.XXXXXXXX)"
chmod 700 "$TMP"
network="vencira-real-login-https-$$"
db="vencira-real-login-pg-$$"
server="vencira-real-login-srv-$$"
image="vencira-real-login-lab:$$"
network_created=0
image_built=0
cleanup() {
  local status=$?
  trap - EXIT
  D rm -f "$server" "$db" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_built" == 1 ]]; then D image rm "$image" >/dev/null 2>&1 || true; fi
  rm -f "$TMP/env" "$TMP/cert.pem" "$TMP/key.pem"
  rmdir "$TMP" || true
  local stable=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" != "${BEFORE[$service]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "LOGIN_MFA_REAL_HTTPS_LIVE_CONTAINERS_UNCHANGED=OK"; else
    echo "LOGIN_MFA_REAL_HTTPS_LIVE_CONTAINERS_UNCHANGED=FAIL"; status=9
  fi
  echo "LOGIN_MFA_REAL_HTTPS_DEPLOY_EXECUTED=NO"
  echo "LOGIN_MFA_REAL_HTTPS_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "LOGIN_MFA_REAL_HTTPS_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

D build -q -t "$image" ./backend >/dev/null
image_built=1
echo "LOGIN_MFA_REAL_HTTPS_IMAGE_BUILT=OK"
password="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
mfa_key="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
# This Base32 factor is synthetic and only exists in the disposable test DB.
mfa_secret="JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"
cat > "$TMP/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=login-mfa.test
DJANGO_HTTPS_BEHIND_PROXY=1
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=loginlab
POSTGRES_USER=loginlab
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$db
VENCIRA_MFA_FERNET_KEYS=$mfa_key
VENCIRA_MFA_LAB_TOTP_SECRET=$mfa_secret
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_NATIVE_SERVICE_CANDIDATE=0
VENCIRA_NATIVE_SESSION_LAB=0
EOF
chmod 600 "$TMP/env"
openssl req -x509 -nodes -newkey rsa:2048 \
 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 1 \
 -subj "/CN=login-mfa.test" -addext "subjectAltName=DNS:login-mfa.test" >/dev/null 2>&1
chmod 644 "$TMP/key.pem" "$TMP/cert.pem"
D network create --internal "$network" >/dev/null
network_created=1
test "$(D network inspect -f '{{.Internal}}' "$network")" = true || exit 4
echo "LOGIN_MFA_REAL_HTTPS_INTERNAL_NETWORK=OK"
D run --rm -d --name "$db" --network "$network" \
 --tmpfs /var/lib/postgresql/data:rw,size=384m \
 -e POSTGRES_DB=loginlab -e POSTGRES_USER=loginlab -e POSTGRES_PASSWORD="$password" \
 postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U loginlab -d loginlab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" == YES || exit 5
echo "LOGIN_MFA_REAL_HTTPS_PG17_READY=YES"
django() { D run --rm --network "$network" --env-file "$TMP/env" "$image" python manage.py "$@"; }
django check >/dev/null
django migrate --noinput >/dev/null
echo "LOGIN_MFA_REAL_HTTPS_FULL_SCHEMA_DISPOSABLE=OK"
FIXTURE="$(cat <<'PY'
import os
from django.contrib.auth import get_user_model
from django.utils import timezone
from reminders.models import UserMfaState
from reminders.mfa_secrets import encrypt_totp_secret
User=get_user_model()
basic=User.objects.create_user(username="https-basic",password="synthetic-https-password-2026",last_login=timezone.now())
mfa=User.objects.create_user(username="https-mfa",password="synthetic-https-password-2026",last_login=timezone.now())
UserMfaState.objects.create(user=mfa, enabled=True, encrypted_totp_secret=encrypt_totp_secret(
    os.environ["VENCIRA_MFA_LAB_TOTP_SECRET"],user_id=mfa.pk,keys=[os.environ["VENCIRA_MFA_FERNET_KEYS"]]))
assert UserMfaState.objects.filter(user=mfa,enabled=True).exists()
print("LOGIN_MFA_REAL_HTTPS_SYNTHETIC_USERS_READY=OK")
PY
)"
django shell -c "$FIXTURE" | grep -Fx "LOGIN_MFA_REAL_HTTPS_SYNTHETIC_USERS_READY=OK"

D run -d --name "$server" --network "$network" --network-alias login-mfa.test \
 --env-file "$TMP/env" -e PYTHONPATH=/app \
 --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
 --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
 -v "$ROOT/scripts/login_mfa_operational_https_server.py:/opt/login_mfa_operational_https_server.py:ro" \
 -v "$TMP/cert.pem:/tmp/login-mfa-cert.pem:ro" -v "$TMP/key.pem:/tmp/login-mfa-key.pem:ro" \
 "$image" python -u /opt/login_mfa_operational_https_server.py >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket;s=socket.create_connection(("127.0.0.1",8443),timeout=1);s.close()' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
if [[ "$ready" != YES ]]; then
  echo "LOGIN_MFA_REAL_HTTPS_SERVER_READY=FAIL"
  D inspect -f 'SERVER_STATUS={{.State.Status}} EXIT={{.State.ExitCode}}' "$server" || true
  D logs --tail 50 "$server" || true
  exit 7
fi
echo "LOGIN_MFA_REAL_HTTPS_SERVER_READY=YES"
D run --rm --network "$network" --env-file "$TMP/env" -e PYTHONPATH=/app \
 --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
 --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
 -v "$ROOT/scripts/login_mfa_operational_https_probe.py:/opt/login_mfa_operational_https_probe.py:ro" \
 -v "$TMP/cert.pem:/tmp/login-mfa-cert.pem:ro" \
 "$image" python -u /opt/login_mfa_operational_https_probe.py
echo "LOGIN_MFA_REAL_HTTPS_GATE=PASS"
