#!/usr/bin/env bash
# D24 grouped isolated PG17 read-race + Flutter pagination gate.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D24_%s=%s\n' "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark NATIVE_RELEASE_AUTHORIZED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(id -u)" != 0 ]] || { mark RESULT 2; exit 2; }
head="$(git rev-parse --verify HEAD)" || { mark RESULT 2; exit 2; }
main="$(git rev-parse --verify refs/remotes/origin/main)" || { mark RESULT 2; exit 2; }
[[ "$head" == "$main" && -z "$(git status --porcelain)" ]] || {
  mark MAIN_CLEAN FAIL
  mark RESULT 2
  exit 2
}
mark MAIN_CLEAN PASS
sudo -n docker version >/dev/null 2>&1 || {
  mark DOCKER_ACCESS FAIL
  mark RESULT 3
  exit 3
}
declare -A previous
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(sudo -n docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || {
    mark DEV_IDENTITY FAIL
    mark RESULT 3
    exit 3
  }
  previous["$name"]="$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
cleanup(){
  local rc=$?
  trap - EXIT
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    if [[ "$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" != "${previous[$name]}" ]]; then
      rc=9
    fi
  done
  if [[ "$rc" == 9 ]]; then mark DEV_CONTAINERS_UNCHANGED FAIL; else mark DEV_CONTAINERS_UNCHANGED OK; fi
  mark DEPLOY_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark NATIVE_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh || exit 2
python3 scripts/main_d18_native_auth_release_fence_static.py || exit 3
mark OPERATIONAL_ROUTE_FENCE PASS
bash scripts/native_i8k_recovery_http_pg17_isolated.sh || {
  mark PG17_CONCURRENCY_PAGINATION FAIL
  exit 4
}
mark PG17_CONCURRENCY_PAGINATION PASS
sudo -n docker run --rm -v "$root/clients/flutter:/source:ro" \
  ghcr.io/cirruslabs/flutter:3.44.0 sh -euc '
  cp -a /source /tmp/vencira-d24-flutter
  cd /tmp/vencira-d24-flutter
  flutter pub get
  flutter analyze
  flutter test --reporter expanded test/native_workspace_read_port_test.dart test/native_api_transport_test.dart test/native_api_endpoint_test.dart
' || {
  mark FLUTTER_PAGINATION_GATE FAIL
  exit 5
}
mark FLUTTER_PAGINATION_GATE PASS
mark PAGINATION_LIMIT 50
mark ACTUAL_TLS_NETWORK_GATE NOT_RUN
mark NATIVE_ISSUER_ENABLED NO
