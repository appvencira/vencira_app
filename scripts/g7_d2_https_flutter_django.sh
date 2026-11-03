#!/usr/bin/env bash
# G7-D2: Dart/Flutter verified HTTPS -> isolated Django test issuer.
# Disposable Docker-internal network and SQLite tmpfs; NO published ports.
set -euo pipefail

cd "$(dirname "$0")/.."
DOCKER=(sudo docker)
NETWORK="vencira-g7d2-isolated-$$"
SERVER="vencira-g7d2-django-$$"
IMAGE="vencira-m3-backend-test"
TMP="$(mktemp -d /tmp/vencira-g7d2.XXXXXXXX)"
chmod 700 "$TMP"

cleanup() {
  local status=$?
  trap - EXIT
  "${DOCKER[@]}" rm -f "$SERVER" >/dev/null 2>&1 || true
  "${DOCKER[@]}" network rm "$NETWORK" >/dev/null 2>&1 || true
  if [[ "$TMP" == /tmp/vencira-g7d2.* && -d "$TMP" ]]; then
    sudo rm -rf -- "$TMP" || true
  fi
  echo "G7_D2_GATE_RESULT=$status"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$status"
}
trap cleanup EXIT

echo "G7_D2_LAB_ISOLATION=START"
python3 scripts/n1_static_security_gate.py
bash -n scripts/g7_d2_https_flutter_django.sh
"${DOCKER[@]}" build -t "$IMAGE" ./backend

# Preload package dependencies before opening the internal-only Docker network.
mkdir -p "$TMP/pub-cache"
"${DOCKER[@]}" run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$TMP/pub-cache:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter pub get && flutter analyze tool/g7_d2_https_probe.dart test/g7_d2_https_live_test.dart'

"${DOCKER[@]}" network create --internal "$NETWORK" >/dev/null
test "$("${DOCKER[@]}" network inspect -f '{{.Internal}}' "$NETWORK")" = "true"

# Django: read-only filesystem, SQLite/certificate in tmpfs, no host port.
"${DOCKER[@]}" run --rm -d \
  --name "$SERVER" \
  --network "$NETWORK" \
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
  -e DJANGO_SECRET_KEY=g7-d2-only-disposable-secret-key-never-for-production-2026 \
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
  echo "G7_D2_FIXTURE_READY=FAIL" >&2
  "${DOCKER[@]}" logs --tail 35 "$SERVER" >&2 || true
  exit 1
fi
echo "G7_D2_FIXTURE_READY=OK"

G7_D2_PEER_IPV4="$("${DOCKER[@]}" inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$SERVER")"
if [[ ! "$G7_D2_PEER_IPV4" =~ ^[0-9]{1,3}([.][0-9]{1,3}){3}$ ]]; then
  echo "G7_D2_PRIVATE_PEER=INVALID" >&2
  exit 1
fi

# Export the PUBLIC temporary CA via the running container. Never export a key.
if ! "${DOCKER[@]}" exec "$SERVER" sh -c \
    'test -f /tmp/g7d2-ready && test -s /tmp/g7d2-public-ca.pem'; then
  echo "G7_D2_PUBLIC_CA_SOURCE=MISSING" >&2
  exit 1
fi
if ! "${DOCKER[@]}" exec "$SERVER" cat /tmp/g7d2-public-ca.pem > "$TMP/public-ca.pem"; then
  echo "G7_D2_PUBLIC_CA_STREAM=FAIL" >&2
  exit 1
fi

# CA certificate contains no private key. World-readable bind-mount file is
# intentional: Flutter's container user need not match the Ubuntu user.
# The host's parent TMP directory remains 0700; no private PEM is shared.
chmod 0644 "$TMP/public-ca.pem"
python3 - "$TMP/public-ca.pem" <<'PY'
import ssl
import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_text(encoding="ascii")
assert raw.count("-----BEGIN CERTIFICATE-----") == 1
assert raw.count("-----END CERTIFICATE-----") == 1
assert "PRIVATE KEY" not in raw
assert len(raw) <= 16384
assert len(ssl.PEM_cert_to_DER_cert(raw)) > 128
PY
echo "G7_D2_PUBLIC_CA_READY=OK"

# Flutter uses real HttpClient/IOClient. The TCP peer is the private IPv4,
# but URI/SNI remains dev.vencira.es and the ephemeral CA must verify.
# The PEM is a read-only mount; we do NOT use badCertificateCallback.
"${DOCKER[@]}" run --rm \
  --network "$NETWORK" \
  --tmpfs /tmp:rw,nosuid,size=268435456,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$TMP/pub-cache:/tmp/g7-d2-pub-cache" \
  -v "$TMP/public-ca.pem:/tmp/g7d2-public-ca.pem:ro" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e G7_D2_ISOLATED_NETWORK_ACK=1 \
  -e G7_D2_CA_FILE=/tmp/g7d2-public-ca.pem \
  -e G7_D2_PEER_IPV4="$G7_D2_PEER_IPV4" \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter test --no-pub test/g7_d2_https_live_test.dart --reporter expanded' \
  | tee "$TMP/flutter-result.log"

# A skipped or failed Flutter test must not produce a false success marker.
grep -Fq -- 'G7_E_MFA_HTTPS_RESULT=0' "$TMP/flutter-result.log"
grep -Fq -- 'G7_E_REFRESH_REPLAY_RESULT=0' "$TMP/flutter-result.log"
grep -Fq -- 'G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0' "$TMP/flutter-result.log"
grep -Fq -- 'All tests passed!' "$TMP/flutter-result.log"
echo "G7_E_HTTPS_MFA_REFRESH=OK"
echo "G7_D2_FLUTTER_DJANGO_HTTPS=OK"
