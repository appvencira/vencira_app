#!/usr/bin/env bash
# G7-D2: Flutter/Dart -> real verified HTTPS -> Django test issuer.
# Isolated Docker-only runtime: no published ports, no live DB or credentials.
# The image used for Django is rebuilt from the local checkout.
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

# Dependency acquisition occurs BEFORE the isolated network is created.
# The runtime test uses the cached package resolution with --internal only.
mkdir -p "$TMP/pub-cache"
"${DOCKER[@]}" run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$TMP/pub-cache:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter pub get && flutter analyze tool/g7_d2_https_probe.dart'

"${DOCKER[@]}" network create --internal "$NETWORK" >/dev/null
test "$("${DOCKER[@]}" network inspect -f '{{.Internal}}' "$NETWORK")" = "true"

# Django runs without root on a read-only filesystem. Its SQLite DB,
# temporary certificate/private key, and generated CA are in tmpfs.
# The TLS service listens on 8443 ONLY in the private Docker network.
# No -p, --publish, host networking, or host secrets are permitted.
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

# Export ONLY the public test CA; private keys stay in the backend tmpfs.
"${DOCKER[@]}" cp "$SERVER:/tmp/g7d2-public-ca.pem" "$TMP/public-ca.pem" >/dev/null
test -s "$TMP/public-ca.pem"

# Under --internal, dev.vencira.es is the Docker network alias of the
# disposable Django fixture, not a public DNS name. Dart sends HTTPS with
# original SNI/host and validates the temporary CA (no badCertificateCallback).
"${DOCKER[@]}" run --rm \
  --network "$NETWORK" \
  --read-only \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$TMP/pub-cache:/tmp/g7-d2-pub-cache" \
  -v "$TMP/public-ca.pem:/tmp/g7d2-public-ca.pem:ro" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e G7_D2_ISOLATED_NETWORK_ACK=1 \
  -e G7_D2_CA_FILE=/tmp/g7d2-public-ca.pem \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'dart run tool/g7_d2_https_probe.dart'

echo "G7_D2_FLUTTER_DJANGO_HTTPS=OK"
