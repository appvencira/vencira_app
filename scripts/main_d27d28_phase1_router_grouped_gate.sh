#!/usr/bin/env bash
# D27-D28 grouped phase-1: native mobile routing behavior + inherited barriers.
# No production routing, issuer activation, Android installation or deployment.
set -Eeuo pipefail
set +x
umask 077
mark() { printf 'D27D28_P1_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark OPERATIONAL_ISSUER_ENABLED NO
mark ANDROID_MAIN_AUTH_ENABLED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(id -u)" -ne 0 ]] || exit 2
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" &&
    -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
sudo -n docker info >/dev/null || { mark DOCKER_ACCESS FAIL; exit 2; }

# Inherited policy gate uses no Docker and must pass first.
bash scripts/main_d27d28_grouped_contract_gate.sh
mark HARD_RELEASE_FENCES PASS

declare -A before
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(sudo -n docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name")" == vencira_localcheck ]] || exit 3
  before["$name"]="$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS

tag="vencira-d28-router-$$"
work="$tag-work"
cache="$tag-cache"
temp="$tag-temp"
created=()
cleanup() {
  local rc=$?
  trap - EXIT
  for volume in "${created[@]}"; do
    sudo -n docker volume rm "$volume" >/dev/null 2>&1 || true
  done
  local safe=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" == "${before[$name]}" ]] || safe=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$safe" == YES ]] && echo OK || echo FAIL)"
  [[ "$safe" == YES ]] || rc=9
  mark RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for volume in "$work" "$cache" "$temp"; do
  sudo -n docker volume create "$volume" >/dev/null
  created+=("$volume")
done
available="$(sudo -n docker run --rm --network none -v "$temp:/tmp" \
  --entrypoint df ghcr.io/cirruslabs/flutter:3.44.0 -Pk /tmp |
  awk 'NR==2 {print $4}')"
[[ "$available" =~ ^[0-9]+$ && "$available" -ge 1048576 ]] || {
  mark FLUTTER_TEMP_CAPACITY FAIL
  exit 4
}
mark FLUTTER_TEMP_CAPACITY PASS
sudo -n docker run --rm --network none \
  -v "$root/clients/flutter:/source:ro" -v "$work:/work" \
  -v "$cache:/pub" -e PUB_CACHE=/pub -w /work \
  ghcr.io/cirruslabs/flutter:3.44.0 \
  sh -euc 'cp -a /source/. /work/; flutter pub get; flutter analyze; flutter test --reporter expanded test/native_d28_mobile_entry_router_test.dart test/native_android_startup_boundary_test.dart test/native_i8l_http_recovery_integration_test.dart'
mark FLUTTER_ROUTER_REGRESSION PASS
mark NATIVE_FIRST_VS_RECOVERY_ROUTING_CANDIDATE YES
mark OPERATIONAL_ISSUER_ENABLED NO
mark ANDROID_MAIN_AUTH_ENABLED NO
