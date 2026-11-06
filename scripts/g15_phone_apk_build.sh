#!/usr/bin/env bash
# G15 self-contained DEBUG notification lab, synthetic-only, no Django.
set -euo pipefail
cd "$(dirname "$0")/.."
test "${VENCIRA_G15_LAB_BUILD:-}" = 1
command -v flutter >/dev/null
command -v python3 >/dev/null
python3 scripts/n1_static_security_gate.py
python3 scripts/test_g15_lab_boundary.py
cd clients/flutter
flutter pub get
flutter analyze lib/g15_lab_main.dart lib/g15_lab/physical_notice_checks.dart
flutter build apk --debug --target=lib/g15_lab_main.dart \
  --dart-define=VENCIRA_G15_LAB_BUILD=true --no-pub
APK="build/app/outputs/flutter-apk/app-debug.apk"
test -s "$APK"
AAPT="$(command -v aapt || true)"
if [[ -z "$AAPT" ]]; then
  SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "$SDK" ]]; then
    AAPT="$(find "$SDK/build-tools" -type f -name aapt 2>/dev/null | sort -V | tail -n 1)"
  fi
fi
test -x "$AAPT" || { echo "G15_AAPT_REQUIRED"; exit 2; }
python3 ../../scripts/g15_apk_manifest_gate.py --apk "$APK" --aapt "$AAPT"
mkdir -p build/g15-phone
cp -- "$APK" build/g15-phone/VENCIRA-G15-LAB-debug.apk
(cd build/g15-phone && sha256sum VENCIRA-G15-LAB-debug.apk > VENCIRA-G15-LAB-debug.apk.sha256)
echo "G15_ANDROID_APK_PATH=clients/flutter/build/g15-phone/VENCIRA-G15-LAB-debug.apk"
echo "G15_ANDROID_APK_BUILD=OK"
echo "G15_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
