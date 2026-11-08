#!/usr/bin/env bash
# Build the I8-N standalone debug APK. No API calls and no deployment.
# Uses the Android toolchain in the same Flutter SDK Docker image as prior labs.
set -Eeuo pipefail
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ -f clients/flutter/lib/main_i8n_keystore_lab.dart ]] || exit 2
command -v docker >/dev/null || exit 2
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  [[ "$(D inspect -f '{{.State.Health.Status}}' "$name")" == healthy ]] || exit 3
done
output="$HOME/vencira-i8n-phone"
mkdir -p "$output"
chmod 700 "$output"
# Keep the host repo read-only; all generated files are in the disposable
# container and the single debug APK is copied to a dedicated output folder.
D run --rm \
  -v "$root/clients/flutter:/source:ro" \
  -v "$output:/output" \
  ghcr.io/cirruslabs/flutter:3.44.0 \
  sh -euc '
    cp -a /source /tmp/vencira-i8n-flutter
    cd /tmp/vencira-i8n-flutter
    flutter pub get
    flutter analyze lib/main_i8n_keystore_lab.dart \
      lib/i8o_android_keystore_failure_lab.dart \
      integration_test/native_i8n_android_restart_secure_store_test.dart
    VENCIRA_I8N_LAB_BUILD=1 flutter build apk --debug \
      --target lib/main_i8n_keystore_lab.dart \
      --dart-define=VENCIRA_I8N_ANDROID_LAB=true
    cp build/app/outputs/flutter-apk/app-debug.apk \
      /output/VENCIRA-I8N-Keystore-debug.apk
    chmod 644 /output/VENCIRA-I8N-Keystore-debug.apk
  '
test -s "$output/VENCIRA-I8N-Keystore-debug.apk"
echo "I8N_APK_DEBUG_BUILD=PASS"
echo "I8N_APK_PACKAGE=es.vencira.vencira.i8nlab"
echo "I8N_APK_PATH=$output/VENCIRA-I8N-Keystore-debug.apk"
echo "I8N_APK_DEVICE_TEST=NOT_RUN"
echo "I8O_ANDROID_FAULT_TEST=NOT_RUN"
echo "I8N_APK_DEPLOY_EXECUTED=NO"
echo "I8N_APK_LIVE_MIGRATIONS_EXECUTED=NO"
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
