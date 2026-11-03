#!/usr/bin/env bash
# G9 native boot-gate regression batch: no Django, no issuer, no live sessions.
# The prior G7 real HTTPS and G8 physical Android receipts stay unchanged.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d /tmp/vencira-g9-XXXXXXXX)"
chmod 700 "$TMP"
cleanup() {
  local result=$?
  trap - EXIT
  rm -rf -- "$TMP"
  echo "G9_STARTUP_GATE_RESULT=$result"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$result"
}
trap cleanup EXIT

python3 scripts/n1_static_security_gate.py
bash -n scripts/g9_native_startup_gate.sh

DOCKER=(sudo docker)
PUB_VOLUME="vencira-g7-public-dart-pub-v1"
"${DOCKER[@]}" volume create "$PUB_VOLUME" >/dev/null
"${DOCKER[@]}" run --rm \
  -v "$PWD/clients/flutter:/work" -w /work \
  -v "$PUB_VOLUME:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  ghcr.io/cirruslabs/flutter:stable \
  sh -c '
    set -e
    flutter pub get --offline || flutter pub get
    flutter analyze \
      lib/api/native_mobile_startup_gate.dart \
      lib/api/native_mobile_recovery_entry.dart \
      test/native_mobile_startup_gate_test.dart \
      test/native_mobile_recovery_entry_test.dart
    flutter test --no-pub --reporter expanded \
      test/native_mobile_startup_gate_test.dart \
      test/native_mobile_recovery_entry_test.dart \
      test/native_refresh_recovery_journal_test.dart \
      test/native_recovery_login_gateway_test.dart \
      test/native_session_coordinator_test.dart
  ' > "$TMP/g9-test.log" 2>&1 || {
    tail -n 85 "$TMP/g9-test.log" >&2
    exit 1
  }
grep -Fq -- "No issues found!" "$TMP/g9-test.log" || {
  echo "G9_ANALYZER_NOT_VERIFIED" >&2
  tail -n 85 "$TMP/g9-test.log" >&2
  exit 1
}
grep -Fq -- "All tests passed!" "$TMP/g9-test.log" || {
  echo "G9_UNIT_NOT_VERIFIED" >&2
  tail -n 85 "$TMP/g9-test.log" >&2
  exit 1
}
echo "G9_STARTUP_ANALYZE=OK"
echo "G9_STARTUP_AND_RECOVERY_UNIT=OK"
echo "G9_STARTUP_GATE_BATCH=OK"
