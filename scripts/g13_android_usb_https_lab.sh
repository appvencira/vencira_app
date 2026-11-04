#!/usr/bin/env bash
# G13 two-stage real Android HTTPS test over USB ADB reverse.
# No public listener, no production endpoint, test-only Django+SQLite tmpfs.
# Keep this terminal open while the two mobile stages are being executed.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="usb"
case "${1:-}" in
  "") ;;
  --ssh-tunnel) MODE="ssh_tunnel" ;;
  *)
    echo "G13_USAGE=bash scripts/g13_android_usb_https_lab.sh [--ssh-tunnel]" >&2
    exit 2
    ;;
esac

for cmd in python3 base64; do
  command -v "$cmd" >/dev/null || {
    echo "G13_HOST_DEPENDENCY_MISSING=$cmd" >&2
    exit 2
  }
done
python3 scripts/n1_static_security_gate.py
bash -n scripts/g13_android_usb_https_lab.sh
bash -n scripts/g13_phone_apk_build.sh
python3 - <<'PY'
import ast
from pathlib import Path
path = Path("scripts/g13_usb_loopback_relay.py")
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
print("G13_HOST_RELAY_PYTHON_SYNTAX=OK")
PY

# The original physical USB route remains unchanged. The alternative mode
# runs the exact same server/CA/APK but uses an SSH -L tunnel from Termux.
# Neither mode ever binds 0.0.0.0 or publishes a Docker port.
if [[ "$MODE" == usb ]]; then
  command -v adb >/dev/null || {
    echo "G13_HOST_DEPENDENCY_MISSING=adb" >&2
    exit 2
  }
  ADB_IDS="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ "$(printf '%s\n' "$ADB_IDS" | sed '/^$/d' | wc -l)" != "1" ]]; then
    echo "G13_ADB_REQUIRES_EXACTLY_ONE_AUTHORIZED_DEVICE" >&2
    exit 2
  fi
  if [[ "$ADB_IDS" == emulator-* ]] ||
     [[ "$(adb -s "$ADB_IDS" shell getprop ro.kernel.qemu | tr -d '\r')" == "1" ]]; then
    echo "G13_PHYSICAL_USB_DEVICE_REQUIRED" >&2
    exit 2
  fi
  if adb reverse --list | grep -Fq 'tcp:18743'; then
    echo "G13_ADB_REVERSE_ALREADY_IN_USE" >&2
    exit 2
  fi
  echo "G13_MODE=USB_ADB"
else
  echo "G13_MODE=TERMUX_SSH_LOCAL_FORWARD"
  echo "G13_NO_ADB_REQUIRED=1"
fi

DOCKER=(sudo docker)
NET="vencira-g13-internal-$$"
SERVER="vencira-g13-django-$$"
IMAGE="vencira-g13-django-lab"
PUB_VOLUME="vencira-g7-public-dart-pub-v1"
TMP="$(mktemp -d /tmp/vencira-g13.XXXXXXXX)"
chmod 700 "$TMP"
RELAY_PID=""
REVERSE_SET=0

cleanup() {
  local result=$?
  trap - EXIT
  if [[ "$REVERSE_SET" = 1 ]]; then
    adb reverse --remove tcp:18743 >/dev/null 2>&1 || true
  fi
  if [[ -n "$RELAY_PID" ]]; then
    kill "$RELAY_PID" >/dev/null 2>&1 || true
  fi
  "${DOCKER[@]}" rm -f "$SERVER" >/dev/null 2>&1 || true
  "${DOCKER[@]}" network rm "$NET" >/dev/null 2>&1 || true
  if [[ "$TMP" == /tmp/vencira-g13.* && -d "$TMP" ]]; then
    rm -rf -- "$TMP"
  fi
  echo "G13_USB_LAB_CLEANUP=OK"
  echo "G13_USB_HOST_RUNNER_RESULT=$result"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$result"
}
trap cleanup EXIT INT TERM

"${DOCKER[@]}" build -t "$IMAGE" ./backend
"${DOCKER[@]}" network create --internal "$NET" >/dev/null
test "$("${DOCKER[@]}" network inspect -f '{{.Internal}}' "$NET")" = true

"${DOCKER[@]}" run --rm -d \
  --name "$SERVER" \
  --network "$NET" \
  --network-alias dev.vencira.es \
  --read-only \
  --tmpfs /tmp:rw,nosuid,size=268435456,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 --memory 1536m \
  -e VENCIRA_ENV=test \
  -e VENCIRA_NATIVE_SESSION_LAB=1 \
  -e VENCIRA_DB_ENGINE=sqlite \
  -e G7_D2_ISOLATED_NETWORK_ACK=1 \
  -e DJANGO_DEBUG=0 \
  -e DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,testserver \
  -e DJANGO_SECRET_KEY=g13-disposable-fixture-only-not-operational-2026 \
  "$IMAGE" python -u -m native_sessions_lab.g7_d2_https_fixture >/dev/null

ready=0
for _ in $(seq 1 90); do
  if "${DOCKER[@]}" exec "$SERVER" test -f /tmp/g7d2-ready >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "G13_DISPOSABLE_DJANGO_NOT_READY" >&2
  "${DOCKER[@]}" logs --tail 20 "$SERVER" >&2 || true
  exit 1
fi
echo "G13_DJANGO_TMPFS_READY=OK"

IP="$("${DOCKER[@]}" inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$SERVER")"
python3 - "$IP" <<'PY'
import ipaddress, sys
peer=ipaddress.ip_address(sys.argv[1])
assert peer.version==4 and peer.is_private and not peer.is_loopback
assert not peer.is_multicast and not peer.is_link_local
print("G13_DOCKER_PRIVATE_PEER=OK")
PY

"${DOCKER[@]}" exec "$SERVER" sh -c \
  'test -f /tmp/g7d2-ready && test -s /tmp/g7d2-public-ca.pem'
"${DOCKER[@]}" exec "$SERVER" cat /tmp/g7d2-public-ca.pem > "$TMP/public-ca.pem"
python3 - "$TMP/public-ca.pem" <<'PY'
import ssl, sys
from pathlib import Path
pem=Path(sys.argv[1]).read_text("ascii")
assert pem.count("-----BEGIN CERTIFICATE-----")==1
assert pem.count("-----END CERTIFICATE-----")==1
assert "PRIVATE KEY" not in pem
assert len(ssl.PEM_cert_to_DER_cert(pem))>128
print("G13_PUBLIC_EPHEMERAL_CA=OK")
PY

G13_DISPOSABLE_ACK=1 python3 scripts/g13_usb_loopback_relay.py "$IP" \
  > "$TMP/relay.log" 2>&1 &
RELAY_PID=$!
relay_ready=0
for _ in $(seq 1 20); do
  if grep -Fq 'G13_HOST_LOOPBACK_RELAY_READY=OK' "$TMP/relay.log"; then
    relay_ready=1
    break
  fi
  if ! kill -0 "$RELAY_PID" 2>/dev/null; then break; fi
  sleep 0.2
done
test "$relay_ready" = 1 || {
  echo "G13_HOST_RELAY_NOT_READY" >&2
  exit 1
}
echo "G13_HOST_RELAY_BOUND_LOOPBACK=OK"

# Require verified ephemeral TLS *before* installing anything on the device.
python3 - "$TMP/public-ca.pem" <<'PY'
import socket, ssl, sys
ctx=ssl.create_default_context(cafile=sys.argv[1])
ctx.check_hostname=True
with socket.create_connection(("127.0.0.1",18743),timeout=8) as raw:
    with ctx.wrap_socket(raw,server_hostname="dev.vencira.es") as tls:
        tls.sendall(b"GET /api/v1/mobile/me/ HTTP/1.1\r\nHost: dev.vencira.es\r\nConnection: close\r\n\r\n")
        data=tls.recv(256)
        assert b" 401 " in data.split(b"\r\n",1)[0]
print("G13_HOST_VERIFIED_TLS_AND_UNAUTH_401=OK")
PY

if [[ "$MODE" == usb ]]; then
  adb reverse tcp:18743 tcp:18743
  REVERSE_SET=1
  adb reverse --list | grep -Fq 'tcp:18743 tcp:18743' || {
    echo "G13_ADB_REVERSE_NOT_CONFIRMED" >&2
    exit 1
  }
  echo "G13_USB_ADB_REVERSE=OK"
else
  echo "G13_TERMUX_SSH_FORWARD_REQUIRED=1"
  echo "G13_SSH_FORWARD_TARGET=127.0.0.1:18743"
fi

# Public CA is embedded in this DEBUG binary only. The private CA key
# stays in the isolated Django container's ephemeral filesystem.
CA64="$(base64 -w0 "$TMP/public-ca.pem")"
"${DOCKER[@]}" volume create "$PUB_VOLUME" >/dev/null
"${DOCKER[@]}" run --rm \
  -v "$PWD:/src" -w /src \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e VENCIRA_G13_LAB_BUILD=1 \
  -e G13_LAB_PUBLIC_CA_BASE64="$CA64" \
  ghcr.io/cirruslabs/flutter:stable \
  bash scripts/g13_phone_apk_build.sh

APK="clients/flutter/build/g13-phone/VENCIRA-G13-LAB-debug.apk"
test -s "$APK"
if [[ "$MODE" == usb ]]; then
  adb install -r "$APK" >/dev/null
  echo "G13_ANDROID_DEBUG_APK_INSTALLED=OK"
  echo "G13_USB_LOOPBACK_ONLY=OK"
  echo 'Open VENCIRA G13 TLS on the USB phone and run both phases.'
  echo 'Force-stop/reopen the app between phases. Keep USB and terminal connected.'
else
  echo "G13_TERMUX_SSH_APK_READY=OK"
  echo "G13_TERMUX_SSH_APK_REMOTE_PATH=$PWD/$APK"
  echo 'From Android Termux: use ssh -L 127.0.0.1:18743:127.0.0.1:18743 to this VPS.'
  echo 'Copy APK over authenticated SFTP/SCP, install locally, then run both phases.'
  echo 'Keep Termux tunnel active and VPS tmux session alive until phase 2 ends.'
fi
echo "G13_ANDROID_APP=es.vencira.vencira.g13lab"
echo "G13_LAB_SESSION_ACTIVE=1"
echo "G13_NO_PRODUCTION_NETWORK_OR_DB=1"
echo "G13_LAB_MODE=$MODE"
echo 'Press ENTER ONLY AFTER phone verification or to cancel the lab.'
read -r -p 'G13 lab teardown: ' _
echo "G13_LAB_TEARDOWN_REQUESTED=OK"
