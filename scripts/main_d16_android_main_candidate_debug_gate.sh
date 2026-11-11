#!/usr/bin/env bash
# D16: build and verify current main.dart Android candidate (DEBUG ONLY).
# No installed APK, release signing, backend deployment or live migrations.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D16_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
for k in DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED APK_INSTALLED RELEASE_SIGNED APK_DISTRIBUTED; do mark "$k" NO; done
[[ "$(id -u)" != 0 ]] || { mark UNPRIVILEGED_OPERATOR_REQUIRED FAIL; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for x in git docker sudo sha256sum stat python3; do command -v "$x" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$x"; exit 2; }; done
head="$(git rev-parse --verify HEAD 2>/dev/null)" || { mark MAIN_SYNC FAIL; exit 2; }
remote="$(git rev-parse --verify refs/remotes/origin/main 2>/dev/null)" || { mark MAIN_SYNC FAIL; exit 2; }
status="$(git status --porcelain 2>/dev/null)" || { mark CLEAN_TREE FAIL; exit 2; }
[[ "$head" == "$remote" && -z "$status" ]] || { mark MAIN_SYNC FAIL; exit 2; }
mark MAIN_SYNC PASS
# Prevent carrying operator-side signing material into the container.
for name in VENCIRA_ANDROID_KEYSTORE_PATH VENCIRA_ANDROID_KEYSTORE_PASSWORD VENCIRA_ANDROID_KEY_ALIAS VENCIRA_ANDROID_KEY_PASSWORD; do
  [[ -z "${!name:-}" ]] || { mark RELEASE_SIGNING_ENV_PRESENT FAIL; exit 3; }
done
mark RELEASE_SIGNING_ENV_PRESENT NO
for name in VENCIRA_G8_LAB_BUILD VENCIRA_G12_LAB_BUILD VENCIRA_G13_LAB_BUILD VENCIRA_G15_LAB_BUILD VENCIRA_I8N_LAB_BUILD VENCIRA_I8O_LAB_BUILD VENCIRA_I8P_LAB_BUILD; do
  [[ -z "${!name:-}" ]] || { mark LAB_BUILD_ENV_PRESENT FAIL; exit 3; }
done
mark LAB_BUILD_ENV_PRESENT NO
if ! sudo -n docker version >/dev/null 2>&1; then mark DOCKER_ACCESS FAIL; exit 3; fi
for container in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(sudo -n docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null)" == vencira_localcheck ]] || { mark DEV_IDENTITY FAIL; exit 3; }
done
mark DEV_IDENTITY PASS
declare -A before
for container in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  before["$container"]="$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$container")"
done
output="$HOME/vencira-android-candidate"
[[ "$output" == /home/vencira/vencira-android-candidate ]] || { mark PRIVATE_OUTPUT_LOCATION FAIL; exit 3; }
if [[ -e "$output" ]]; then
  [[ -d "$output" && ! -L "$output" && "$(stat -c '%u:%a' "$output")" == "$(id -u):700" ]] || { mark PRIVATE_OUTPUT_DIRECTORY FAIL; exit 3; }
else
  mkdir -m 700 "$output"
fi
# Do not overwrite any previous artifact: unique checkout-commit directory.
target="$output/$head"
[[ ! -e "$target" ]] || { mark ARTIFACT_ALREADY_EXISTS FAIL; exit 3; }
mkdir -m 700 "$target"
cleanup(){
  local rc=$?
  trap - EXIT
  local unchanged=YES
  for container in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$container" 2>/dev/null || true)" == "${before[$container]}" ]] || unchanged=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$unchanged" == YES ]] && echo OK || echo FAIL)"
  [[ "$unchanged" == YES ]] || rc=9
  if [[ "$rc" -ne 0 ]]; then
    rm -f "$target/VENCIRA-main-candidate-debug.apk" "$target/apk.sha256"
    rmdir "$target" 2>/dev/null || true
  fi
  mark DEPLOY_EXECUTED NO
  mark RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
# Read-only source mount. All Gradle/cache/build output stays in container;
# only one debug apk can be copied back to private output.
if ! sudo -n docker run --rm --network bridge \
    -v "$root/clients/flutter:/source:ro" -v "$target:/output" \
    -e VENCIRA_ANDROID_KEYSTORE_PATH= \
    -e VENCIRA_ANDROID_KEYSTORE_PASSWORD= \
    -e VENCIRA_ANDROID_KEY_ALIAS= \
    -e VENCIRA_ANDROID_KEY_PASSWORD= \
    ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
      cp -a /source /tmp/vencira-d16-candidate
      cd /tmp/vencira-d16-candidate
      flutter pub get
      flutter analyze
      flutter test --reporter compact \
        test/native_i8q_recovery_fault_matrix_test.dart \
        test/native_i8l_http_recovery_integration_test.dart \
        test/native_http_auth_port_test.dart \
        test/native_api_endpoint_test.dart
      flutter build apk --debug --target lib/main.dart
      cp build/app/outputs/flutter-apk/app-debug.apk \
        /output/VENCIRA-main-candidate-debug.apk
      chmod 644 /output/VENCIRA-main-candidate-debug.apk
    '; then
  mark FLUTTER_ANALYZE_TEST_BUILD FAIL
  exit 5
fi
mark FLUTTER_ANALYZE_TEST_BUILD PASS
apk="$target/VENCIRA-main-candidate-debug.apk"
[[ -s "$apk" && ! -L "$apk" ]] || { mark APK_PRESENT FAIL; exit 6; }
# Debug build is not a distribution release APK, irrespective of signing.
python3 - "$apk" <<'PY'
import sys, zipfile
path=sys.argv[1]
with zipfile.ZipFile(path) as z:
    names=set(z.namelist())
    assert "AndroidManifest.xml" in names
    assert "classes.dex" in names
    assert "lib/arm64-v8a/libflutter.so" in names
    assert z.testzip() is None
PY
mark APK_ZIP_INTEGRITY PASS
(cd "$target" && sha256sum VENCIRA-main-candidate-debug.apk > apk.sha256)
mark APK_SHA256_RECORDED PASS
mark APK_MAIN_ENTRYPOINT YES
mark APK_DEBUG_ONLY YES
mark APK_PHYSICAL_DEVICE_TEST NOT_RUN
mark APK_NATIVE_HTTPS_RELEASE_GATE NOT_VERIFIED
mark APK_RELEASE_SIGNING_GATE NOT_VERIFIED
echo "D16_APK_PATH=$apk"
