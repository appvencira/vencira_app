#!/usr/bin/env bash
# D17-B: verify new Android startup boundary with Flutter test/analyze.
# No native login endpoint is enabled by this gate.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D17B_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark APK_SIGNED NO
mark AUTH_PRODUCTION_ENABLED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
head="$(git rev-parse --verify HEAD 2>/dev/null)" || { mark MAIN_SYNC FAIL; exit 2; }
remote="$(git rev-parse --verify refs/remotes/origin/main 2>/dev/null)" || { mark MAIN_SYNC FAIL; exit 2; }
status="$(git status --porcelain 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
[[ "$head" == "$remote" && -z "$status" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
sudo -n docker version >/dev/null 2>&1 || { mark DOCKER_ACCESS FAIL; exit 3; }
declare -A previous
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(sudo -n docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || { mark DEV_IDENTITY FAIL; exit 3; }
  previous["$name"]="$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
cleanup(){
  local rc=$?
  trap - EXIT
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" == "${previous[$name]}" ]] || rc=9
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$rc" != 9 ]] && echo OK || echo FAIL)"
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
sudo -n docker run --rm -v "$root/clients/flutter:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
  cp -a /source /tmp/vencira-d17b
  cd /tmp/vencira-d17b
  flutter pub get
  flutter analyze
  flutter test --reporter expanded \
    test/native_android_startup_boundary_test.dart \
    test/native_i8q_recovery_fault_matrix_test.dart \
    test/native_i8l_http_recovery_integration_test.dart
' || { mark FLUTTER_GATE FAIL; exit 4; }
mark FLUTTER_GATE PASS
mark NATIVE_STARTUP_INTEGRATED YES
mark AUTH_PRODUCTION_ENABLED NO
