#!/usr/bin/env bash
# I8-H Android physical native HTTPS -> disposable PG17, SSH localhost only.
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
TMP="$(mktemp -d /tmp/vencira-native-i8h.XXXXXXXX)"
chmod 700 "$TMP"
network="vencira-native-i8h-$$"
db="vencira-native-i8h-pg-$$"
server="vencira-native-i8h-srv-$$"
image="vencira-native-i8h-lab:$$"
network_created=0
image_built=0
relay_pid=""
cleanup() {
  local status=$?
  trap - EXIT
  if [[ -n "$relay_pid" ]]; then kill "$relay_pid" >/dev/null 2>&1 || true; fi
  D rm -f "$server" "$db" >/dev/null 2>&1 || true
  if [[ "$network_created" == 1 ]]; then D network rm "$network" >/dev/null 2>&1 || true; fi
  if [[ "$image_built" == 1 ]]; then D image rm "$image" >/dev/null 2>&1 || true; fi
  rm -f "$TMP/env" "$TMP/cert.pem" "$TMP/key.pem" "$TMP/relay.log"
  rmdir "$TMP" || true
  local stable=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" != "${BEFORE[$service]}" ]]; then stable=NO; fi
  done
  if [[ "$stable" == YES ]]; then echo "NATIVE_I8H_LIVE_CONTAINERS_UNCHANGED=OK"; else
    echo "NATIVE_I8H_LIVE_CONTAINERS_UNCHANGED=FAIL"; status=9
  fi
  echo "NATIVE_I8H_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8H_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8H_PHYSICAL_PHONE_VERIFIED=NOT_ASSERTED_BY_VPS"
  echo "NATIVE_I8H_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT

# Fail fast on Dart diagnostics BEFORE building images or starting a DB/TLS lab.
# Guard against accidentally truncated or repeated Dart UI code.
python3 - <<'PY'
from pathlib import Path
source = Path("clients/flutter/lib/i8h_lab_main.dart").read_text(encoding="utf-8")
checks = (
    source.count("Widget build(") == 1,
    source.count("} catch (error) {") == 1,
    source.count("} finally {") == 1,
    source.count("RegExp(") == 2,
    "RegExp(r'^[A-Z0-9_]{1,45}$').hasMatch(stage)" in source,
    "RegExp(r'^NATIVE_I8H_[A-Z0-9_]{1,80}$').hasMatch(rawCode)" in source,
    "NATIVE_I8H_FAILURE_CODE=$safeCode" in source,
)
if not all(checks):
    raise SystemExit("NATIVE_I8H_UI_STRUCTURAL_PREFLIGHT=FAIL")
print("NATIVE_I8H_UI_STRUCTURAL_PREFLIGHT=OK")
PY

pubvol="vencira-g7-public-dart-pub-v1"
D volume create "$pubvol" >/dev/null
D run --rm -v "$ROOT/clients/flutter:/work" -w /work \
  -v "$pubvol:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable sh -ec '
    flutter pub get --offline || flutter pub get
    flutter analyze lib/i8h_lab_main.dart lib/i8h_lab/physical_mfa_checks.dart
  '
echo "NATIVE_I8H_FLUTTER_PREFLIGHT_ANALYZE=OK"

D build -q -t "$image" ./backend >/dev/null
image_built=1
echo "NATIVE_I8H_IMAGE_BUILT=OK"
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
D network create --internal "$network" >/dev/null
network_created=1
test "$(D network inspect -f '{{.Internal}}' "$network")" = true || exit 4
echo "NATIVE_I8H_INTERNAL_NETWORK=OK"
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
echo "NATIVE_I8H_PG17_READY=YES"
django() { D run --rm --network "$network" --env-file "$TMP/env" "$image" python manage.py "$@"; }
django check >/dev/null
# Prevent silent false-positive setup: the real WSGI process must see G5
# keys through Django settings, not only Docker env or Django test overrides.
django shell -c 'from django.conf import settings; assert settings.VENCIRA_ENV == "test"; assert settings.VENCIRA_NATIVE_SERVICE_CANDIDATE; assert settings.VENCIRA_NATIVE_BEARER_ENABLED is False; assert isinstance(settings.VENCIRA_G5_AUDIT_KEY, str) and len(settings.VENCIRA_G5_AUDIT_KEY) >= 32; assert isinstance(settings.VENCIRA_G5_ABUSE_KEY, str) and len(settings.VENCIRA_G5_ABUSE_KEY) >= 32; print("NATIVE_I8H_G5_SETTINGS_READY=OK")' | grep -Fx 'NATIVE_I8H_G5_SETTINGS_READY=OK'
django migrate --noinput >/dev/null
echo "NATIVE_I8H_FULL_SCHEMA_DISPOSABLE=OK"
django makemigrations native_mobile_service --check --dry-run --noinput >/dev/null
echo "NATIVE_I8H_MIGRATION_PARITY=OK"
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
print("NATIVE_I8H_SYNTHETIC_USERS_READY=OK")
PY
)"
django shell -c "$FIXTURE" | grep -Fx "NATIVE_I8H_SYNTHETIC_USERS_READY=OK"

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
  echo "NATIVE_I8H_SERVER_READY=FAIL"
  D inspect -f 'SERVER_STATUS={{.State.Status}} EXIT={{.State.ExitCode}}' "$server" || true
  D logs --tail 50 "$server" || true
  exit 7
fi
echo "NATIVE_I8H_SERVER_READY=YES"
peer="$(D inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$server")"
python3 - "$peer" <<'PY'
import ipaddress,sys
p=ipaddress.ip_address(sys.argv[1])
assert p.version==4 and p.is_private and not p.is_loopback and not p.is_link_local
print("NATIVE_I8H_DOCKER_PRIVATE_PEER=OK")
PY
python3 - <<'PY'
import socket
with socket.socket() as s:
    s.bind(("127.0.0.1",18743))
print("NATIVE_I8H_LOOPBACK_FREE=OK")
PY
G13_DISPOSABLE_ACK=1 python3 scripts/g13_usb_loopback_relay.py "$peer" > "$TMP/relay.log" 2>&1 &
relay_pid=$!
relay_ready=NO
for _ in $(seq 1 40); do
  if grep -Fq 'G13_HOST_LOOPBACK_RELAY_READY=OK' "$TMP/relay.log"; then relay_ready=YES; break; fi
  if ! kill -0 "$relay_pid" 2>/dev/null; then break; fi
  sleep 0.25
done
test "$relay_ready" == YES || { echo "NATIVE_I8H_LOOPBACK_RELAY=FAIL"; exit 8; }
python3 - "$TMP/cert.pem" <<'PY'
import socket,ssl,sys
ctx=ssl.create_default_context(cafile=sys.argv[1])
with socket.create_connection(("127.0.0.1",18743),timeout=8) as raw:
    with ctx.wrap_socket(raw,server_hostname="dev.vencira.es") as s:
        s.sendall(b"GET /api/v1/mobile/me/ HTTP/1.1\r\nHost: dev.vencira.es\r\nConnection: close\r\n\r\n")
        line=s.recv(200).split(b"\r\n",1)[0]
        assert b" 401 " in line, "Unexpected TLS response"
print("NATIVE_I8H_HOST_HTTPS_401=PASS")
PY
ca64="$(base64 -w0 "$TMP/cert.pem")"
pubvol="vencira-g7-public-dart-pub-v1"
D volume create "$pubvol" >/dev/null
D run --rm -v "$ROOT:/src" -w /src \
  -v "$pubvol:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e VENCIRA_I8H_LAB_BUILD=1 \
  -e I8H_PUBLIC_CA_BASE64="$ca64" \
  ghcr.io/cirruslabs/flutter:stable sh -ec '
    cd clients/flutter
    flutter pub get --offline || flutter pub get
    flutter analyze lib/i8h_lab_main.dart lib/i8h_lab/physical_mfa_checks.dart
    echo NATIVE_I8H_FLUTTER_ANALYZE=OK
    flutter build apk --debug --no-pub --target=lib/i8h_lab_main.dart \
      --dart-define=VENCIRA_I8H_LAB_BUILD=true \
      --dart-define=I8H_PUBLIC_CA_BASE64="$I8H_PUBLIC_CA_BASE64"
    apk=build/app/outputs/flutter-apk/app-debug.apk
    test -s "$apk"
    aapt_bin="$(command -v aapt || true)"
    if [ -z "$aapt_bin" ]; then
      sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
      aapt_bin="$(find "$sdk/build-tools" -type f -name aapt | sort -V | tail -n 1)"
    fi
    test -x "$aapt_bin"
    package="$("$aapt_bin" dump badging "$apk" | sed -n "s/^package: name=\x27\([^\x27]*\)\x27.*/\1/p" | head -n 1)"
    test "$package" = "es.vencira.vencira.i8hlab" || {
      echo NATIVE_I8H_PACKAGE_MISMATCH; exit 1;
    }
    mkdir -p build/i8h-phone
    cp "$apk" build/i8h-phone/VENCIRA-I8H-LAB-debug.apk
    (cd build/i8h-phone && sha256sum VENCIRA-I8H-LAB-debug.apk > VENCIRA-I8H-LAB-debug.apk.sha256)
    echo NATIVE_I8H_DEBUG_APK_PACKAGE=es.vencira.vencira.i8hlab
    echo NATIVE_I8H_DEBUG_APK_BUILD=PASS
  '
echo "NATIVE_I8H_APK_PATH=$ROOT/clients/flutter/build/i8h-phone/VENCIRA-I8H-LAB-debug.apk"
echo "NATIVE_I8H_PHONE_RESULT=PENDING"
echo "NATIVE_I8H_NO_OPERATIONAL_NETWORK_OR_DB=YES"
echo "NATIVE_I8H_LAB_SESSION_ACTIVE=1"
echo "Set up Termux SSH tunnel: ssh -L 127.0.0.1:18743:127.0.0.1:18743 <user>@<VPS>"
read -r -p 'Complete Android test while lab/tunnel stay active. ENTER tears down: ' _
echo "NATIVE_I8H_LAB_TEARDOWN=OK"
