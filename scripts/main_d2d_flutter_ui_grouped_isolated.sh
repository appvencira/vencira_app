#!/usr/bin/env bash
# D2-D grouped Flutter widget UI tests. No DEV data, migrations, or deploy.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D2D_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
root="$(git rev-parse --show-toplevel)"
cd "$root"
for tool in git docker; do
  command -v "$tool" >/dev/null || { mark MISSING_TOOL "$tool"; exit 2; }
done
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  mark MAIN_HEAD_REQUIRED FAIL; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE_REQUIRED FAIL; exit 2; }
if [[ "$(id -u)" == 0 ]]; then
  D(){ docker "$@"; }
else
  command -v sudo >/dev/null || { mark SUDO_REQUIRED YES; exit 2; }
  sudo -v
  D(){ sudo docker "$@"; }
fi
declare -A live
for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(D inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$service" 2>/dev/null)" == vencira_localcheck ]] || {
    mark DEV_IDENTITY FAIL; exit 3;
  }
  live["$service"]="$(D inspect -f '{{.Id}}:{{.Image}}' "$service")"
done
mark DEV_IDENTITY PASS
cleanup(){
  local rc=$?
  trap - EXIT
  local intact=YES
  for service in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(D inspect -f '{{.Id}}:{{.Image}}' "$service" 2>/dev/null || true)" == "${live[$service]}" ]] || intact=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$intact" == YES ]] && echo OK || echo FAIL)"
  [[ "$intact" == YES ]] || rc=9
  mark DEPLOY_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
D run --rm --memory 4g --tmpfs /tmp:rw,size=3g,mode=1777 \
  -v "$root/clients/flutter:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
    cp -a /source /tmp/d2d-flutter
    cd /tmp/d2d-flutter
    flutter pub get >/dev/null
    flutter analyze --no-pub
    printf "D2D_FLUTTER_ANALYZE=PASS\n"
    flutter test --no-pub test/d2d_real_editor_gestures_test.dart
    printf "D2D_REAL_EDITOR_GESTURES=PASS\n"
    flutter test --no-pub test/renewal_editor_test.dart
    printf "D2D_EXISTING_EDITOR_REGRESSION=PASS\n"
  ' || { mark FLUTTER_UI_GROUP FAIL; exit 8; }
mark FLUTTER_UI_GROUP PASS
mark REAL_CHROMIUM_GUI_CLICK_VERIFIED NO
mark REAL_DEV_DATA_USED NO
mark FLUTTER_EDITOR_DESKTOP_MOBILE_GROUP_GATE PASS
