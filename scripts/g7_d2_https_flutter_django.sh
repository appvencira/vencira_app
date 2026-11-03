#!/usr/bin/env bash
# G7-D2: Dart/Flutter verified HTTPS -> isolated Django test issuer.
# Disposable Docker-internal network and SQLite tmpfs; NO published ports.
set -euo pipefail

# One Docker lab per invocation. Focused checks run only one established
# group; --all is required at the end of each macrofase / in CI.
GROUP="all"
FAST=0
case "${1:---all}" in
  --all)
    test "$#" -le 1 || exit 2
    ;;
  --fast)
    test "$#" -eq 1 || exit 2
    GROUP="f"
    FAST=1
    ;;
  --group)
    test "$#" -eq 2 || exit 2
    GROUP="$2"
    FAST=1
    case "$GROUP" in d2|e|f) ;; *) echo "Invalid test group" >&2; exit 2 ;; esac
    ;;
  *)
    echo "Usage: $0 [--all|--fast|--group d2|e|f]" >&2
    exit 2
    ;;
esac
echo "G7_BATCH_GROUP=$GROUP"
echo "G7_BATCH_FAST=$FAST"

cd "$(dirname "$0")/.."
DOCKER=(sudo docker)
NETWORK="vencira-g7d2-isolated-$$"
SERVER="vencira-g7d2-django-$$"
IMAGE="vencira-m3-backend-test"
# Package cache contains public dependencies only, no credentials or artifacts.
PUB_VOLUME="vencira-g7-public-dart-pub-v1"
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
"${DOCKER[@]}" volume create "$PUB_VOLUME" >/dev/null
"${DOCKER[@]}" run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e G7_BATCH_FAST="$FAST" \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'if [ "${G7_BATCH_FAST}" = "1" ]; then flutter pub get --offline || flutter pub get; echo G7_BATCH_ANALYZE=SKIPPED_FAST_MODE; else flutter pub get && flutter analyze tool/g7_d2_https_probe.dart test/g7_d2_https_live_test.dart; fi'

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
# Capture verbose per-request metadata in a temporary file. Show only
# group-level results on PASS; on failure show diagnostic tail. The shell
# preserves the Flutter process exit status, never declaring a false PASS.
if ! "${DOCKER[@]}" run --rm \
  --network "$NETWORK" \
  --tmpfs /tmp:rw,nosuid,size=268435456,mode=1777 \
  --cap-drop ALL --security-opt no-new-privileges \
  --pids-limit 128 \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -v "$TMP/public-ca.pem:/tmp/g7d2-public-ca.pem:ro" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e G7_D2_ISOLATED_NETWORK_ACK=1 \
  -e G7_D2_CA_FILE=/tmp/g7d2-public-ca.pem \
  -e G7_D2_PEER_IPV4="$G7_D2_PEER_IPV4" \
  -e G7_LAB_GROUP="$GROUP" \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c 'flutter test --no-pub test/g7_d2_https_live_test.dart --reporter expanded' \
  > "$TMP/flutter-result.log" 2>&1; then
  tail -n 90 "$TMP/flutter-result.log" >&2
  exit 1
fi

# Distinct suite markers. Focused mode cannot pretend unexecuted groups passed.
required=("G7_LAB_GROUP_COMPLETE=$GROUP" "All tests passed!")
case "$GROUP" in
  all)
    required+=("G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0"
      "G7_E_MFA_HTTPS_RESULT=0"
      "G7_E_REFRESH_REPLAY_RESULT=0"
      "G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0")
    ;;
  d2) required+=("G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0") ;;
  e) required+=("G7_E_MFA_HTTPS_RESULT=0" "G7_E_REFRESH_REPLAY_RESULT=0") ;;
  f) required+=("G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0") ;;
esac
for marker in "${required[@]}"; do
  if ! grep -Fq -- "$marker" "$TMP/flutter-result.log"; then
    echo "G7_BATCH_REQUIRED_MARKER=MISSING" >&2
    tail -n 90 "$TMP/flutter-result.log" >&2
    exit 1
  fi
  echo "$marker"
done
if [[ "$GROUP" == all || "$GROUP" == e ]]; then
  echo "G7_E_HTTPS_MFA_REFRESH=OK"
fi
if [[ "$GROUP" == all || "$GROUP" == f ]]; then
  echo "G7_F_HTTPS_RECOVERY=OK"
fi
if [[ "$GROUP" == all || "$GROUP" == d2 ]]; then
  echo "G7_D2_FLUTTER_DJANGO_HTTPS=OK"
fi
echo "G7_BATCH_RESULT=0"
