#!/usr/bin/env bash
# I8-K recovery-only native JSON MFA over verified TLS and disposable PG17.
# Full migrations ONLY in disposable PG17; no host ports or live DB changes.
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
TMP="$(mktemp -d /tmp/vencira-native-i8k.XXXXXXXX)"
chmod 700 "$TMP"
network="vencira-native-i8k-$$"
db="vencira-native-i8k-pg-$$"
server="vencira-native-i8k-srv-$$"
image="vencira-native-i8k-lab:$$"
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
  if [[ "$stable" == YES ]]; then echo "NATIVE_I8K_LIVE_CONTAINERS_UNCHANGED=OK"; else
    echo "NATIVE_I8K_LIVE_CONTAINERS_UNCHANGED=FAIL"; status=9
  fi
  echo "NATIVE_I8K_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8K_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8K_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

D build -q -t "$image" ./backend >/dev/null
image_built=1
echo "NATIVE_I8K_IMAGE_BUILT=OK"
password="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
mfa_key="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
# This Base32 factor is synthetic and only exists in the disposable test DB.
mfa_secret="JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"
cat > "$TMP/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=native-i8k.test
DJANGO_HTTPS_BEHIND_PROXY=1
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=i8klab
POSTGRES_USER=i8klab
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$db
VENCIRA_MFA_FERNET_KEYS=$mfa_key
VENCIRA_MFA_LAB_TOTP_SECRET=$mfa_secret
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_NATIVE_SERVICE_CANDIDATE=1
VENCIRA_NATIVE_SESSION_LAB=0
VENCIRA_I8D_HTTP_LAB=1
VENCIRA_I8K_RECOVERY_LAB=1
VENCIRA_I8K_NETWORK_ISOLATED=1
VENCIRA_I8D_MFA_KEY=$mfa_key
VENCIRA_G5_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_G5_ABUSE_KEY=$(openssl rand -hex 36)
VENCIRA_I8K_MFA_SECRET=$mfa_secret

EOF
chmod 600 "$TMP/env"
openssl req -x509 -nodes -newkey rsa:2048 \
 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 1 \
 -subj "/CN=native-i8k.test" -addext "subjectAltName=DNS:native-i8k.test" >/dev/null 2>&1
chmod 644 "$TMP/key.pem" "$TMP/cert.pem"
D network create --internal "$network" >/dev/null
network_created=1
test "$(D network inspect -f '{{.Internal}}' "$network")" = true || exit 4
echo "NATIVE_I8K_INTERNAL_NETWORK=OK"
D run --rm -d --name "$db" --network "$network" \
 --tmpfs /var/lib/postgresql/data:rw,size=384m \
 -e POSTGRES_DB=i8klab -e POSTGRES_USER=i8klab -e POSTGRES_PASSWORD="$password" \
 postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U i8klab -d i8klab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" == YES || exit 5
echo "NATIVE_I8K_PG17_READY=YES"
django() { D run --rm --network "$network" --env-file "$TMP/env" "$image" python manage.py "$@"; }
django check >/dev/null
# Prevent silent false-positive setup: the real WSGI process must see G5
# keys through Django settings, not only Docker env or Django test overrides.
django shell -c 'from django.conf import settings; assert settings.VENCIRA_ENV == "test"; assert settings.VENCIRA_NATIVE_SERVICE_CANDIDATE; assert settings.VENCIRA_NATIVE_BEARER_ENABLED is False; assert isinstance(settings.VENCIRA_G5_AUDIT_KEY, str) and len(settings.VENCIRA_G5_AUDIT_KEY) >= 32; assert isinstance(settings.VENCIRA_G5_ABUSE_KEY, str) and len(settings.VENCIRA_G5_ABUSE_KEY) >= 32; print("NATIVE_I8K_G5_SETTINGS_READY=OK")' | grep -Fx 'NATIVE_I8K_G5_SETTINGS_READY=OK'
django migrate --noinput >/dev/null
echo "NATIVE_I8K_FULL_SCHEMA_DISPOSABLE=OK"
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
echo "NATIVE_I8K_MIGRATION_PARITY=OK"
# All HTTP/PG17 recovery regressions run before starting a TLS listener.
# Django uses a secondary test database inside the disposable PG17 network.
django test \
  native_mobile_service.test_i8k_recovery_http_pg17 \
  native_mobile_service.test_i8j_recovery_pg17 \
  native_mobile_service.test_i8i_non_mfa_recovery_policy_pg17 \
  --verbosity 1
echo "NATIVE_I8K_RECOVERY_JSON_PG17=PASS"
FIXTURE="$(cat <<'PY'
import os
from django.contrib.auth import get_user_model
from reminders.models import UserMfaState
from reminders.mfa_secrets import encrypt_totp_secret

User = get_user_model()
key = os.environ["VENCIRA_I8D_MFA_KEY"]
for username, secret in [
    ("i8k-recovery-synthetic", os.environ["VENCIRA_I8K_MFA_SECRET"]),
]:
    user = User.objects.create_user(
        username=username, password="synthetic-i8k-password",
    )
    UserMfaState.objects.create(
        user=user, enabled=True, session_epoch=1,
        encrypted_totp_secret=encrypt_totp_secret(
            secret, user_id=user.pk, keys=[key],
        ),
    )
print("NATIVE_I8K_SYNTHETIC_RECOVERY_READY=OK")
PY
)"
django shell -c "$FIXTURE" | grep -Fx "NATIVE_I8K_SYNTHETIC_RECOVERY_READY=OK"

D run -d --name "$server" --network "$network" --network-alias native-i8k.test \
 --env-file "$TMP/env" -e PYTHONPATH=/app \
 --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
 --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
 -v "$ROOT/scripts/native_i8k_https_server.py:/opt/native_i8k_https_server.py:ro" \
 -v "$TMP/cert.pem:/tmp/i8k-cert.pem:ro" -v "$TMP/key.pem:/tmp/i8k-key.pem:ro" \
 "$image" python -u /opt/native_i8k_https_server.py >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket;s=socket.create_connection(("127.0.0.1",8443),timeout=1);s.close()' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
if [[ "$ready" != YES ]]; then
  echo "NATIVE_I8K_SERVER_READY=FAIL"
  D inspect -f 'SERVER_STATUS={{.State.Status}} EXIT={{.State.ExitCode}}' "$server" || true
  D logs --tail 50 "$server" || true
  exit 7
fi
echo "NATIVE_I8K_SERVER_READY=YES"
D run --rm --network "$network" --env-file "$TMP/env" -e PYTHONPATH=/app \
 --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
 --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
 -v "$ROOT/scripts/native_i8k_https_probe.py:/opt/native_i8k_https_probe.py:ro" \
 -v "$TMP/cert.pem:/tmp/i8k-cert.pem:ro" \
 "$image" python -u /opt/native_i8k_https_probe.py
echo "NATIVE_I8K_REAL_HTTPS_GATE=PASS"
