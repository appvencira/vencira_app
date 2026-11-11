#!/usr/bin/env bash
# D18: one grouped native-security lab gate: static + PG17 + real TLS Flutter.
# All containers/networks/databases are synthetic and disposable.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D18_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark RELEASE_AUTHORIZED NO
[[ "$(id -u)" != 0 ]] || { mark NONROOT_REQUIRED FAIL; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for cmd in git python3 docker sudo; do
  command -v "$cmd" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$cmd"; exit 2; }
done
head="$(git rev-parse --verify HEAD 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
origin="$(git rev-parse --verify refs/remotes/origin/main 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
status="$(git status --porcelain 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
[[ "$head" == "$origin" && -z "$status" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
for script in scripts/native_i8k_recovery_http_pg17_isolated.sh scripts/main_i8m_flutter_real_https_pg17_isolated.sh; do
  [[ -f "$script" && ! -L "$script" ]] || { mark SCRIPT_MISSING FAIL; exit 2; }
  bash -n "$script" || { mark SCRIPT_SYNTAX FAIL; exit 2; }
done
mark LAB_SCRIPT_SYNTAX PASS
sudo -n docker version >/dev/null 2>&1 || { mark DOCKER_ACCESS FAIL; exit 3; }
declare -A before
for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
  [[ "$(sudo -n docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null)" == vencira_localcheck ]] || { mark DEV_IDENTITY FAIL; exit 3; }
  before["$name"]="$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name")"
done
mark DEV_IDENTITY PASS
cleanup(){
  local rc=$?
  trap - EXIT
  local same=YES
  for name in vencira_localcheck-api-1 vencira_localcheck-db-1 vencira_localcheck-web_preview-1; do
    [[ "$(sudo -n docker inspect -f '{{.Id}}:{{.Image}}' "$name" 2>/dev/null || true)" == "${before[$name]}" ]] || same=NO
  done
  mark DEV_CONTAINERS_UNCHANGED "$([[ "$same" == YES ]] && echo OK || echo FAIL)"
  [[ "$same" == YES ]] || rc=9
  mark LIVE_RESTORE_EXECUTED NO
  mark LIVE_MIGRATIONS_EXECUTED NO
  mark DEPLOY_EXECUTED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
if ! python3 scripts/main_d18_native_auth_release_fence_static.py; then
  mark STATIC_FENCE FAIL
  exit 4
fi
mark STATIC_FENCE PASS

# Existing I8-K creates a disposable PG17, builds a candidate image,
# verifies HTTP password/MFA/recovery contracts and no operational URL route.
if ! bash scripts/native_i8k_recovery_http_pg17_isolated.sh; then
  mark PG17_NATIVE_HTTP_GATE FAIL
  exit 5
fi
mark PG17_NATIVE_HTTP_GATE PASS

# Existing I8-M tests Flutter client against real TLS certificate with
# temporary isolated Django/PG17, including account-wide recovery and
# failed-vault-write revocation. No public hostname or host ports.
if ! bash scripts/main_i8m_flutter_real_https_pg17_isolated.sh; then
  mark FLUTTER_REAL_TLS_RECOVERY_GATE FAIL
  exit 6
fi
mark FLUTTER_REAL_TLS_RECOVERY_GATE PASS
mark NATIVE_AUTH_OPERATIONAL_READINESS BLOCKED
mark AUTH_PRODUCTION_ENABLED NO
mark NATIVE_AUTH_TEST_LABS_GROUPED PASS
