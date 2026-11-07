#!/usr/bin/env bash
# I8-G dedicated isolated debug APK: real Android secure-storage/force-stop lab.
# Explicit no release, no backend connectivity, no production credentials.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [[ "$(id -u)" != 0 ]]; then sudo -v; fi
D() { if [[ "$(id -u)" == 0 ]]; then docker "$@"; else sudo docker "$@"; fi; }
for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  test "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$s")" = vencira_localcheck || exit 3
done
declare -A before
for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  before[$s]="$(D inspect -f '{{.Id}}:{{.Image}}' "$s")"
done
cleanup() {
  local status=$?
  trap - EXIT
  local stable=YES
  for s in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$s" 2>/dev/null || true)" != "${before[$s]}" ]]; then stable=NO; status=9; fi
  done
  echo "NATIVE_I8G_BATCH_DEV_CONTAINERS_UNCHANGED=$stable"
  echo "NATIVE_I8G_BATCH_PHYSICAL_PHONE_EXECUTED=NO"
  echo "NATIVE_I8G_BATCH_DEPLOY_EXECUTED=NO"
  echo "NATIVE_I8G_BATCH_LIVE_MIGRATIONS_EXECUTED=NO"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  echo "NATIVE_I8G_BATCH_LOCAL_RESULT=$status"
  exit "$status"
}
trap cleanup EXIT
# Stage 1: reuse the already-reviewed Flutter contract tests.
bash scripts/native_i8g_android_vault_static_gate.sh
echo "NATIVE_I8G_BATCH_STATIC=PASS"

volume="vencira-g7-public-dart-pub-v1"
D volume create "$volume" >/dev/null
D run --rm \
  -v "$ROOT:/src" -w /src \
  -v "$volume:/tmp/g7-d2-pub-cache" \
  -e PUB_CACHE=/tmp/g7-d2-pub-cache \
  -e VENCIRA_I8G_LAB_BUILD=1 \
  ghcr.io/cirruslabs/flutter:stable \
  sh -ec '
    cd clients/flutter
    flutter pub get --offline || flutter pub get
    flutter analyze lib/i8g_lab_main.dart integration_test/native_i8g_android_secure_storage_test.dart
    echo NATIVE_I8G_BATCH_MAIN_ANALYZE=OK
    flutter build apk --debug --no-pub --target=lib/i8g_lab_main.dart \
      --dart-define=VENCIRA_I8G_DEVICE_TEST=true
    bin=build/app/outputs/flutter-apk/app-debug.apk
    test -s "$bin"
    aapt_bin="$(command -v aapt || true)"
    if [ -z "$aapt_bin" ]; then
      sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
      test -d "$sdk/build-tools"
      aapt_bin="$(find "$sdk/build-tools" -type f -name aapt | sort -V | tail -n 1)"
    fi
    test -x "$aapt_bin"
    package="$("$aapt_bin" dump badging "$bin" |
      sed -n "s/^package: name=\x27\([^\x27]*\)\x27.*/\1/p" | head -n 1)"
    test "$package" = "es.vencira.vencira.i8glab" || {
      echo NATIVE_I8G_BATCH_UNEXPECTED_PACKAGE; exit 1;
    }
    mkdir -p build/i8g-phone
    cp "$bin" build/i8g-phone/VENCIRA-I8G-LAB-debug.apk
    (cd build/i8g-phone && sha256sum VENCIRA-I8G-LAB-debug.apk > VENCIRA-I8G-LAB-debug.apk.sha256)
    echo NATIVE_I8G_BATCH_APK_PACKAGE=es.vencira.vencira.i8glab
    echo NATIVE_I8G_BATCH_APK_BUILD=PASS
  '
echo "NATIVE_I8G_BATCH_APK_PATH=$ROOT/clients/flutter/build/i8g-phone/VENCIRA-I8G-LAB-debug.apk"
echo "NATIVE_I8G_BATCH_GATE=PASS"
