#!/usr/bin/env bash
# Build a DEBUG-ONLY, independently installable physical-phone G8 test APK.
# No release signing, production API, real credentials or database migration.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || {
  echo "G8_PHONE_FLUTTER=NOT_INSTALLED" >&2
  exit 2
}
command -v python3 >/dev/null || exit 2

# These source controls run before any Android Gradle build.
python3 scripts/n1_static_security_gate.py
bash -n scripts/g8_phone_apk_build.sh
test -f clients/flutter/lib/g8_lab_main.dart
test -f clients/flutter/lib/g8_lab/physical_store_checks.dart

cd clients/flutter
flutter pub get
flutter analyze \
  lib/g8_lab_main.dart \
  lib/g8_lab/physical_store_checks.dart \
  integration_test/g8_protected_store_device_test.dart

# Exactly two independent checks: Dart refuses unflagged/release runtime and
# Gradle changes only debug application ID if this build-only env is present.
# The APK's final package ID is independently verified with Android aapt.
VENCIRA_G8_LAB_BUILD=1 flutter build apk --debug \
  --target=lib/g8_lab_main.dart \
  --dart-define=VENCIRA_G8_LAB_BUILD=true \
  --no-pub

apk="build/app/outputs/flutter-apk/app-debug.apk"
test -s "$apk" || {
  echo "G8_PHONE_APK_BUILD=MISSING" >&2
  exit 1
}

aapt_bin="$(command -v aapt || true)"
if [[ -z "$aapt_bin" ]]; then
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$sdk" && -d "$sdk/build-tools" ]]; then
    aapt_bin="$(find "$sdk/build-tools" -type f -name aapt | sort -V | tail -n 1)"
  fi
fi
if [[ -z "$aapt_bin" || ! -x "$aapt_bin" ]]; then
  echo "G8_PHONE_APK_ID_VERIFY=NO_AAPT" >&2
  exit 1
fi

package="$("$aapt_bin" dump badging "$apk" |
  sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" | head -n 1)"
if [[ "$package" != "es.vencira.vencira.g8lab" ]]; then
  echo "G8_PHONE_APK_ID_VERIFY=DENIED_WRONG_PACKAGE" >&2
  exit 1
fi
echo "G8_PHONE_APK_ID_VERIFY=OK"
echo "G8_PHONE_PACKAGE=$package"

mkdir -p build/g8-phone
cp -- "$apk" build/g8-phone/VENCIRA-G8-LAB-debug.apk
(
  cd build/g8-phone
  sha256sum VENCIRA-G8-LAB-debug.apk > VENCIRA-G8-LAB-debug.apk.sha256
)
echo "G8_PHONE_APK_BUILD=OK"
echo "G8_PHONE_APK_PATH=clients/flutter/build/g8-phone/VENCIRA-G8-LAB-debug.apk"
echo "G8_PHONE_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
