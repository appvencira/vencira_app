#!/usr/bin/env bash
# G8 - explicitly opted-in Android EMULATOR secure-storage integration lab.
# This runner does not connect to any server or start VENCIRA authentication.
# It refuses real devices and existing application installations to avoid
# replacing a user's app or touching their Android data.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$#" -ne 1 || ! "${1:-}" =~ ^emulator-[0-9]+$ ]]; then
  echo "G8_DEVICE=DENIED: supply one explicit disposable emulator-PORT serial" >&2
  echo "Usage: bash scripts/g8_android_store_lab.sh emulator-5554" >&2
  exit 2
fi
SERIAL="$1"
command -v adb >/dev/null || { echo "G8_ADB=NOT_INSTALLED" >&2; exit 2; }
command -v flutter >/dev/null || { echo "G8_FLUTTER=NOT_INSTALLED" >&2; exit 2; }

if [[ "$(adb -s "$SERIAL" get-state 2>/dev/null)" != "device" ]]; then
  echo "G8_EMULATOR=NOT_CONNECTED" >&2
  exit 2
fi

is_emulator="$(adb -s "$SERIAL" shell getprop ro.kernel.qemu | tr -d '\r\n')"
if [[ "$is_emulator" != "1" ]]; then
  echo "G8_EMULATOR=DENIED_NON_EMULATOR" >&2
  exit 2
fi
# Flutter debug integration tests install a test APK under the application id.
# Never replace even an existing debug/preview VENCIRA installation.
existing="$(adb -s "$SERIAL" shell pm path es.vencira.vencira | tr -d '\r')"
if [[ -n "$existing" ]]; then
  echo "G8_EMULATOR=DENIED_VENCIRA_ALREADY_INSTALLED" >&2
  exit 2
fi
echo "G8_EMULATOR_ISOLATED=OK"
echo "G8_NO_EXISTING_APPLICATION=OK"
echo "G8_NO_NETWORK_BACKEND=1"

TMP="$(mktemp -d /tmp/vencira-g8.XXXXXXXX)"
chmod 700 "$TMP"
cleanup() {
  local status=$?
  trap - EXIT
  if [[ "$TMP" == /tmp/vencira-g8.* && -d "$TMP" ]]; then
    rm -rf -- "$TMP"
  fi
  echo "G8_EMULATOR_GATE_RESULT=$status"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit "$status"
}
trap cleanup EXIT

# The test's injected flutter_secure_storage namespace is reserved entirely
# for synthetic values. It has NO HTTP requests or production credentials.
flutter pub get
flutter analyze integration_test/g8_protected_store_device_test.dart

if ! flutter test --no-pub \
    -d "$SERIAL" \
    integration_test/g8_protected_store_device_test.dart \
    --reporter expanded > "$TMP/device-result.log" 2>&1; then
  tail -n 80 "$TMP/device-result.log" >&2
  exit 1
fi
for marker in "G8_ANDROID_PROTECTED_STORE_RESULT=0" "All tests passed!"; do
  if ! grep -Fq -- "$marker" "$TMP/device-result.log"; then
    echo "G8_RESULT_MARKER=MISSING" >&2
    tail -n 80 "$TMP/device-result.log" >&2
    exit 1
  fi
  echo "$marker"
done
echo "G8_ANDROID_EMULATOR_STORE=OK"
