#!/usr/bin/env bash
# D27 Android physical Android HTTPS recovery + real Keystore, via SSH loopback.
# Entire Django/PG17 stack is test-only and disposable; no public listener.
set -Eeuo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for cmd in docker openssl python3; do command -v "$cmd" >/dev/null || exit 2; done
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
declare -A before
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  [[ "$(D inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]] || exit 3
  before["$name"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
tmp="$(mktemp -d /tmp/vencira-d27-android.XXXXXXXX)"
chmod 700 "$tmp"
tag="vencira-d27-android-$$"
network="$tag-net"
db="$tag-db"
server="$tag-server"
img="$tag:lab"
image_created=0
network_created=0
relay_pid=
cleanup() {
  local code=$?
  trap - EXIT INT TERM
  if [[ -n "$relay_pid" ]]; then kill "$relay_pid" >/dev/null 2>&1 || true; wait "$relay_pid" 2>/dev/null || true; fi
  D rm -f "$server" "$db" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_created" == 1 ]]; then D image rm "$img" >/dev/null 2>&1 || true; fi
  rm -f "$tmp/env" "$tmp/cert.pem" "$tmp/key.pem" "$tmp/relay.log"
  rmdir "$tmp" 2>/dev/null || true
  local same=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${before[$name]}" ]]; then same=NO; fi
  done
  if [[ "$same" == YES ]]; then
    echo 'D27_ANDROID_DEV_CONTAINERS_UNCHANGED=OK'
  else
    echo 'D27_ANDROID_DEV_CONTAINERS_UNCHANGED=FAIL'
    code=9
  fi
  echo 'D27_ANDROID_DEPLOY_EXECUTED=NO'
  echo 'D27_ANDROID_LIVE_MIGRATIONS_EXECUTED=NO'
  echo 'MFA_RELEASE_AUTHORIZED=NO'
  echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
  echo "D27_ANDROID_LAB_RESULT=$code"
  exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

D build -q -t "$img" ./backend >/dev/null
image_created=1
echo 'D27_ANDROID_DJANGO_DISPOSABLE_IMAGE=OK'
dbpass="$(openssl rand -hex 24)"
key="$(openssl rand -hex 36)"
mfa="$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '\n')"
cat > "$tmp/env" <<EOF
VENCIRA_ENV=test
DJANGO_DEBUG=0
DJANGO_ALLOWED_HOSTS=dev.vencira.es
DJANGO_SECRET_KEY=$key
VENCIRA_DB_ENGINE=postgresql
POSTGRES_DB=i8klab
POSTGRES_USER=i8klab
POSTGRES_PASSWORD=$dbpass
POSTGRES_HOST=$db
VENCIRA_NATIVE_SERVICE_CANDIDATE=1
VENCIRA_I8D_HTTP_LAB=1
VENCIRA_D27_REAL_TLS_LAB=1
VENCIRA_D27_HTTP_LAB=1
VENCIRA_D27_CORE_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_D27_CORE_ABUSE_KEY=$(openssl rand -hex 36)
VENCIRA_I8K_RECOVERY_LAB=1
VENCIRA_I8K_NETWORK_ISOLATED=1
VENCIRA_I8M_FLUTTER_INTERNAL_ONLY=1
VENCIRA_I8D_MFA_KEY=$mfa
VENCIRA_MFA_FERNET_KEYS=$mfa
VENCIRA_MFA_ENROLLMENT_ENABLED=0
VENCIRA_G5_AUDIT_KEY=$(openssl rand -hex 36)
VENCIRA_G5_ABUSE_KEY=$(openssl rand -hex 36)
EOF
chmod 600 "$tmp/env"
openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 1 \
  -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
  -subj '/CN=dev.vencira.es' \
  -addext 'subjectAltName=DNS:dev.vencira.es' >/dev/null 2>&1
chmod 644 "$tmp/cert.pem" "$tmp/key.pem"

D network create --internal "$network" >/dev/null
network_created=1
[[ "$(D network inspect -f '{{.Internal}}' "$network")" == true ]] || exit 4
echo 'D27_ANDROID_NETWORK_INTERNAL=PASS'
D run --rm -d --name "$db" --network "$network" \
  --tmpfs /var/lib/postgresql/data:rw,size=384m \
  -e POSTGRES_DB=i8klab -e POSTGRES_USER=i8klab -e POSTGRES_PASSWORD="$dbpass" \
  postgres:17-alpine >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$db" pg_isready -U i8klab -d i8klab >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || exit 5
echo 'D27_ANDROID_EPHEMERAL_PG17_READY=PASS'
django() { D run --rm --network "$network" --env-file "$tmp/env" "$img" python manage.py "$@"; }
django check >/dev/null
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
django migrate --noinput >/dev/null
echo 'D27_ANDROID_EPHEMERAL_SCHEMA=PASS'

fixture="$(cat <<'PY'
import os
from django.contrib.auth import get_user_model
from reminders.models import UserMfaState
from reminders.mfa_secrets import encrypt_totp_secret
secret='GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'
key=os.environ['VENCIRA_MFA_FERNET_KEYS']
user=get_user_model().objects.create_user(
    username='i8p-recovery',password='synthetic-i8p-password')
UserMfaState.objects.create(
    user=user,enabled=True,session_epoch=1,
    encrypted_totp_secret=encrypt_totp_secret(
        secret,user_id=user.pk,keys=[key]))
print('D27_ANDROID_PG17_SYNTHETIC_ACCOUNT=PASS')
PY
)"
django shell -c "$fixture" | grep -Fx 'D27_ANDROID_PG17_SYNTHETIC_ACCOUNT=PASS'

D run -d --name "$server" --network "$network" \
  --network-alias dev.vencira.es --env-file "$tmp/env" \
  --sysctl net.ipv4.ip_unprivileged_port_start=0 \
  -e PYTHONPATH=/app --read-only \
  --tmpfs /tmp:rw,size=64m,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  -v "$root/scripts/native_i8k_https_server.py:/opt/i8k_server.py:ro" \
  -v "$tmp/cert.pem:/tmp/i8k-cert.pem:ro" \
  -v "$tmp/key.pem:/tmp/i8k-key.pem:ro" \
  "$img" python -u /opt/i8k_server.py >/dev/null
ready=NO
for _ in $(seq 1 45); do
  if D exec "$server" python -c 'import socket; s=socket.create_connection(("127.0.0.1",443),1);s.close()' >/dev/null 2>&1; then ready=YES; break; fi
  sleep 1
done
[[ "$ready" == YES ]] || exit 6
echo 'D27_ANDROID_TLS_SERVER_INTERNAL_READY=PASS'

# Bind relay ONLY to localhost of VPS; remote TCP/HTTP exposure forbidden.
peer="$(D inspect -f "{{(index .NetworkSettings.Networks \"$network\").IPAddress}}" "$server")"
if [[ -z "$peer" ]]; then echo 'D27_ANDROID_DOCKER_PRIVATE_PEER_MISSING' >&2; exit 7; fi
VENCIRA_I8P_DISPOSABLE_ACK=1 python3 \
  "$root/scripts/main_i8p_ssh_tls_loopback_relay.py" "$peer" \
  > "$tmp/relay.log" 2>&1 &
relay_pid=$!
relay_ready=NO
for _ in $(seq 1 30); do
  if ! kill -0 "$relay_pid" 2>/dev/null; then break; fi
  if python3 - <<'PY'
import socket
try:
    with socket.create_connection(('127.0.0.1',18743),timeout=1): pass
except OSError:
    raise SystemExit(1)
PY
  then relay_ready=YES; break; fi
  sleep 1
done
[[ "$relay_ready" == YES ]] || { echo 'D27_ANDROID_SSH_RELAY_READY=FAIL' >&2; exit 8; }
echo 'D27_ANDROID_SSH_RELAY_LOOPBACK_ONLY=PASS'

# This debug APK reuses the audited I8-P physical Keystore test entrypoint.
# The TLS endpoint now serves D27 exclusively; no candidate issuer paths.
# The Docker build copies a PUBLIC CA into --dart-define, but never any
# server key, environment secret, database credentials or user records.
out="$HOME/vencira-d27-android-phone"
mkdir -p "$out"
chmod 700 "$out"
ca_b64="$(base64 -w0 "$tmp/cert.pem")"
D run --rm \
  -v "$root/clients/flutter:/source:ro" -v "$out:/output" \
  -e I8P_PUBLIC_CA_B64="$ca_b64" \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
    cp -a /source /tmp/vencira-flutter
    cd /tmp/vencira-flutter
    flutter pub get
    flutter analyze lib/main_i8p_android_https_lab.dart
    VENCIRA_I8P_LAB_BUILD=1 flutter build apk --debug \
      --target lib/main_i8p_android_https_lab.dart \
      --dart-define=VENCIRA_I8P_ANDROID_LAB=true \
      --dart-define=VENCIRA_I8P_PUBLIC_CA_B64="$I8P_PUBLIC_CA_B64"
    cp build/app/outputs/flutter-apk/app-debug.apk \
      /output/VENCIRA-D27-Android-HTTPS-debug.apk
    chmod 644 /output/VENCIRA-D27-Android-HTTPS-debug.apk
  '
test -s "$out/VENCIRA-D27-Android-HTTPS-debug.apk"
echo 'I8P_ANDROID_APK_DEBUG_BUILD=PASS'
echo 'I8P_ANDROID_PACKAGE=es.vencira.vencira.i8plab'
echo "I8P_ANDROID_APK_PATH=$out/VENCIRA-D27-Android-HTTPS-debug.apk"
echo 'D27_ANDROID_RELEASE_AUTHORIZED=NO'
echo 'D27_ANDROID_PHONE_TEST_RUNNING=YES'

# Intentional interactive hold; keeps the temporary server reachable through
# the operator's authenticated SSH connection, without a public listener.
echo 'Connect Termux: ssh -N -L 127.0.0.1:18743:127.0.0.1:18743 YOUR_EXISTING_VPS_HOST'
echo 'Copy and install only the D27 Android debug APK. Run the single phone test.'
echo 'Press ENTER after collecting phone screenshot to verify PG17 and teardown.'
IFS= read -r _

post="$(cat <<'PY'
from django.contrib.auth import get_user_model
from native_mobile_service.models import MobileDeviceSession,MobileAccountFence
user=get_user_model().objects.get(username='i8p-recovery')
assert MobileAccountFence.objects.get(user=user).generation == 1
assert MobileDeviceSession.objects.filter(user=user).count() == 1
assert MobileDeviceSession.objects.filter(
    user=user,revoked_at__isnull=True).count() == 0
assert MobileDeviceSession.objects.filter(
    user=user,revoked_at__isnull=False).count() == 1
print('D27_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS')
PY
)"
django shell -c "$post" | grep -Fx 'D27_ANDROID_PG17_RECOVERED_SESSION_REVOKED=PASS'
echo 'D27_ANDROID_TLS_MFA_KEYSTORE_GATE=PASS'
