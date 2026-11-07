#!/usr/bin/env bash
# I8-F Flutter real HTTPS -> isolated I8-E native service, PG17 temp database.
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
TMP="$(mktemp -d /tmp/vencira-native-i8f.XXXXXXXX)"
chmod 700 "$TMP"
network="vencira-native-i8f-$$"
db="vencira-native-i8f-pg-$$"
server="vencira-native-i8f-srv-$$"
image="vencira-native-i8f-lab:$$"
network_created=0
image_built=0
cleanup() {
  local status=$?
  trap - EXIT
  D rm -f "$server" "$db" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_built" == 1 ]]; then D image rm "$image" >/dev/null 2>&1 || true; fi
  rm -f "$TMP/env" "$TMP/cert.pem" "$TMP/key.pem" "$TMP/flutter.log"
  rmdir "$TMP" || true
  local stable=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" != "${BEFORE[$service]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "NATIVE_I8F_LIVE_CONTAINERS_UNCHANGED=OK"; else
    echo "NATIVE_I8F_LIVE_CONTAINERS_UNCHANGED=FAIL"; status=9
  fi
  echo "NATIVE_I8F_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8F_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8F_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

D build -q -t "$image" ./backend >/dev/null
image_built=1
echo "NATIVE_I8F_IMAGE_BUILT=OK"
password="$(openssl rand -hex 24)"
secret="$(openssl rand -hex 36)"
mfa_key="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
# This Base32 factor is synthetic and only exists in the disposable test DB.
mfa_secret="JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP"
cat > "$TMP/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=native-i8e.test,dev.vencira.es
DJANGO_HTTPS_BEHIND_PROXY=1
DJANGO_SECRET_KEY=$secret
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=i8elab
POSTGRES_USER=i8elab
POSTGRES_PASSWORD=$password
POSTGRES_HOST=$db
VENCIRA_MFA_FERNET_KEYS=$mfa_key
VENCIRA_MFA_LAB_TOTP_SECRET=$mfa_secret
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_NATIVE_SERVICE_CANDIDATE=1
VENCIRA_NATIVE_SESSION_LAB=0
VENCIRA_I8D_HTTP_LAB=1
VENCIRA_I8E_NETWORK_ISOLATED=1
VENCIRA_I8D_MFA_KEY=$mfa_key
VENCIRA_G5_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_G5_ABUSE_KEY=$(openssl rand -hex 36)
VENCIRA_I8E_MFA_SECRET=$mfa_secret
VENCIRA_I8E_MFA_LOGOUT_SECRET=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ
EOF
chmod 600 "$TMP/env"
openssl req -x509 -nodes -newkey rsa:2048 \
 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 1 \
 -subj "/CN=native-i8e.test" -addext "subjectAltName=DNS:native-i8e.test,DNS:dev.vencira.es" >/dev/null 2>&1
chmod 644 "$TMP/key.pem" "$TMP/cert.pem"
# Pre-fetch PUBLIC Flutter dependencies while internet is available,
# before switching the actual test client to the internal-only network.
pubvol="vencira-g7-public-dart-pub-v1"
D volume create "$pubvol" >/dev/null
D run --rm -v "$ROOT/clients/flutter:/work" -w /work \
  -v "$pubvol:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter pub get --offline || flutter pub get; flutter analyze tool/native_i8f_https_probe.dart test/native_i8f_https_live_test.dart'
echo "NATIVE_I8F_FLUTTER_ANALYZE=OK"
D network create --internal "$network" >/dev/null
network_created=1
test "$(D network inspect -f '{{.Internal}}' "$network")" = true || exit 4
echo "NATIVE_I8F_INTERNAL_NETWORK=OK"
D run --rm -d --name "$db" --network "$network" \
 --tmpfs /var/lib/postgresql/data:rw,size=384m \
 -e POSTGRES_DB=i8elab -e POSTGRES_USER=i8elab -e POSTGRES_PASSWORD="$password" \
 postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U i8elab -d i8elab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
test "$ready" == YES || exit 5
echo "NATIVE_I8F_PG17_READY=YES"
django() { D run --rm --network "$network" --env-file "$TMP/env" "$image" python manage.py "$@"; }
django check >/dev/null
# Prevent silent false-positive setup: the real WSGI process must see G5
# keys through Django settings, not only Docker env or Django test overrides.
django shell -c 'from django.conf import settings; assert settings.VENCIRA_ENV == "test"; assert settings.VENCIRA_NATIVE_SERVICE_CANDIDATE; assert settings.VENCIRA_NATIVE_BEARER_ENABLED is False; assert isinstance(settings.VENCIRA_G5_AUDIT_KEY, str) and len(settings.VENCIRA_G5_AUDIT_KEY) >= 32; assert isinstance(settings.VENCIRA_G5_ABUSE_KEY, str) and len(settings.VENCIRA_G5_ABUSE_KEY) >= 32; print("NATIVE_I8F_G5_SETTINGS_READY=OK")' | grep -Fx 'NATIVE_I8F_G5_SETTINGS_READY=OK'
django migrate --noinput >/dev/null
echo "NATIVE_I8F_FULL_SCHEMA_DISPOSABLE=OK"
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
echo "NATIVE_I8F_MIGRATION_PARITY=OK"
FIXTURE="$(cat <<'PY'
import os
from django.contrib.auth import get_user_model
from reminders.models import UserMfaState
from reminders.mfa_secrets import encrypt_totp_secret

User = get_user_model()
key = os.environ["VENCIRA_I8D_MFA_KEY"]
for username, secret in [
    ("i8e-synthetic-mfa", os.environ["VENCIRA_I8E_MFA_SECRET"]),
    ("i8e-synthetic-logout", os.environ["VENCIRA_I8E_MFA_LOGOUT_SECRET"]),
]:
    user = User.objects.create_user(
        username=username, password="synthetic-i8e-password",
    )
    UserMfaState.objects.create(
        user=user, enabled=True, session_epoch=1,
        encrypted_totp_secret=encrypt_totp_secret(
            secret, user_id=user.pk, keys=[key],
        ),
    )
print("NATIVE_I8F_SYNTHETIC_USERS_READY=OK")
PY
)"
django shell -c "$FIXTURE" | grep -Fx "NATIVE_I8F_SYNTHETIC_USERS_READY=OK"

D run -d --name "$server" --network "$network" --network-alias native-i8e.test --network-alias dev.vencira.es \
 --env-file "$TMP/env" -e PYTHONPATH=/app \
 --read-only --tmpfs /tmp:rw,size=64m,mode=1777 \
 --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
 -v "$ROOT/scripts/native_i8e_https_server.py:/opt/native_i8e_https_server.py:ro" \
 -v "$TMP/cert.pem:/tmp/i8e-cert.pem:ro" -v "$TMP/key.pem:/tmp/i8e-key.pem:ro" \
 "$image" python -u /opt/native_i8e_https_server.py >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket;s=socket.create_connection(("127.0.0.1",8443),timeout=1);s.close()' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
if [[ "$ready" != YES ]]; then
  echo "NATIVE_I8F_SERVER_READY=FAIL"
  D inspect -f 'SERVER_STATUS={{.State.Status}} EXIT={{.State.ExitCode}}' "$server" || true
  D logs --tail 50 "$server" || true
  exit 7
fi
echo "NATIVE_I8F_SERVER_READY=YES"
# Peer IP inspected from Docker, never resolved to public DNS.
peer="$(D inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$server")"
[[ "$peer" =~ ^[0-9]{1,3}([.][0-9]{1,3}){3}$ ]] || exit 8
echo "NATIVE_I8F_PEER_PRIVATE_IP=CHECKED"
# Certificate is PUBLIC only; no private key reaches Flutter.
chmod 0644 "$TMP/cert.pem"
if ! D run --rm --network "$network" \
  --tmpfs /tmp:rw,size=128m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$ROOT/clients/flutter:/work" -w /work \
  -v "$pubvol:/tmp/g7-d2-pub-cache" \
  -v "$TMP/cert.pem:/tmp/i8f-public-ca.pem:ro" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e VENCIRA_I8F_INTERNAL_ACK=1 \
  -e VENCIRA_I8F_PEER_IPV4="$peer" \
  -e VENCIRA_I8F_CA_FILE=/tmp/i8f-public-ca.pem \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter test --no-pub test/native_i8f_https_live_test.dart --reporter expanded' \
  > "$TMP/flutter.log" 2>&1; then
  tail -n 85 "$TMP/flutter.log" >&2
  exit 10
fi
for marker in \
  "NATIVE_I8F_TLS_VERIFIED_HOSTNAME=PASS" \
  "NATIVE_I8F_PASSWORD_MFA_NO_ISSUANCE=PASS" \
  "NATIVE_I8F_TOTP_ISSUANCE_VAULT_CONFIRMED=PASS" \
  "NATIVE_I8F_BEARER_VERIFIED_ME=PASS" \
  "NATIVE_I8F_LOGOUT_LOCAL_FENCE_CLOSED=PASS" \
  "NATIVE_I8F_LOGOUT_REMOTE_REVOKE_CONFIRMED=PASS" \
  "NATIVE_I8F_FLUTTER_HTTPS_GATE=PASS" \
  "All tests passed!"; do
  if ! grep -Fq "$marker" "$TMP/flutter.log"; then
    echo "NATIVE_I8F_REQUIRED_MARKER_MISSING" >&2
    tail -n 85 "$TMP/flutter.log" >&2
    exit 11
  fi
  echo "$marker"
done
echo "NATIVE_I8F_PG17_FLUTTER_TLS_GATE=PASS"
