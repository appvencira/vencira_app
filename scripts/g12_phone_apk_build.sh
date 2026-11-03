#!/usr/bin/env bash
# G12 independent Android DEBUG-ONLY APK, offline, synthetic data only.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || {
  echo "G12_PHONE_FLUTTER=NOT_INSTALLED" >&2
  exit 2
}
command -v python3 >/dev/null || exit 2

python3 scripts/n1_static_security_gate.py
bash -n scripts/g12_phone_apk_build.sh
test -f clients/flutter/lib/g12_lab_main.dart
test -f clients/flutter/lib/g12_lab/physical_auth_checks.dart

cd clients/flutter
flutter pub get
flutter analyze \
  lib/g12_lab_main.dart \
  lib/g12_lab/physical_auth_checks.dart

VENCIRA_G12_LAB_BUILD=1 flutter build apk --debug \
  --target=lib/g12_lab_main.dart \
  --dart-define=VENCIRA_G12_LAB_BUILD=true \
  --no-pub

apk="build/app/outputs/flutter-apk/app-debug.apk"
test -s "$apk" || {
  echo "G12_PHONE_APK_BUILD=MISSING" >&2
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
  echo "G12_PHONE_APK_ID_VERIFY=NO_AAPT" >&2
  exit 1
fi

package="$("$aapt_bin" dump badging "$apk" |
  sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" | head -n 1)"
if [[ "$package" != "es.vencira.vencira.g12lab" ]]; then
  echo "G12_PHONE_APK_ID_VERIFY=DENIED_WRONG_PACKAGE" >&2
  exit 1
fi
echo "G12_PHONE_APK_ID_VERIFY=OK"
echo "G12_PHONE_PACKAGE=$package"

mkdir -p build/g12-phone
cp -- "$apk" build/g12-phone/VENCIRA-G12-LAB-debug.apk
(
  cd build/g12-phone
  sha256sum VENCIRA-G12-LAB-debug.apk > VENCIRA-G12-LAB-debug.apk.sha256
)

echo "G12_PHONE_APK_BUILD=OK"
echo "G12_PHONE_APK_PATH=clients/flutter/build/g12-phone/VENCIRA-G12-LAB-debug.apk"
echo "G12_PHONE_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
