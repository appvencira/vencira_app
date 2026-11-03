#!/usr/bin/env bash
# G10 opt-in first issuance + durable logout, all isolated Flutter unit tests.
# Does NOT execute Django, production HTTP, G7 HTTPS or G8 Android.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d /tmp/vencira-g10-XXXXXXXX)"
chmod 700 "$TMP"
finish() {
  local result=$?
  trap - EXIT
  rm -rf -- "$TMP"
  echo "G10_ISSUANCE_LOGOUT_GATE_RESULT=$result"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$result"
}
trap finish EXIT

python3 scripts/n1_static_security_gate.py
bash -n scripts/g10_issuance_logout_gate.sh

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
      lib/api/native_first_issuance_entry.dart \
      lib/api/native_session_coordinator.dart \
      lib/api/native_refresh_recovery_journal.dart \
      test/native_first_issuance_entry_test.dart
    flutter test --no-pub --reporter expanded \
      test/native_first_issuance_entry_test.dart \
      test/native_mobile_startup_gate_test.dart \
      test/native_mobile_recovery_entry_test.dart \
      test/native_refresh_recovery_journal_test.dart \
      test/native_recovery_login_gateway_test.dart \
      test/native_session_coordinator_test.dart
  ' > "$TMP/batch.log" 2>&1 || {
    echo "G10_FLUTTER_BATCH=FAIL" >&2
    tail -n 100 "$TMP/batch.log" >&2
    exit 1
  }
grep -Fq -- "No issues found!" "$TMP/batch.log" || {
  echo "G10_FLUTTER_ANALYZE=NOT_VERIFIED" >&2
  exit 1
}
grep -Fq -- "All tests passed!" "$TMP/batch.log" || {
  echo "G10_FLUTTER_UNIT=NOT_VERIFIED" >&2
  exit 1
}
echo "G10_ISSUANCE_ANALYZE=OK"
echo "G10_ISSUANCE_LOGOUT_UNIT=OK"
echo "G10_G9_G6_REGRESSION=OK"
echo "G10_ISSUANCE_LOGOUT_BATCH=OK"
