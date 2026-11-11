#!/usr/bin/env bash
# D25 grouped real HTTPS Flutter ↔ Django workspace read over isolated PG17.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D25_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark AUTH_PRODUCTION_ENABLED NO
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
bash -n scripts/main_d25_native_workspace_real_https_pg17_isolated.sh || {
  mark RESULT 2
  exit 2
}
python3 -m py_compile scripts/native_i8k_https_server.py || {
  mark SERVER_SYNTAX FAIL
  mark RESULT 2
  exit 2
}
mark SERVER_SYNTAX PASS
python3 scripts/main_d18_native_auth_release_fence_static.py || {
  mark RELEASE_FENCE FAIL
  mark RESULT 3
  exit 3
}
mark RELEASE_FENCE PASS
if bash scripts/main_d25_native_workspace_real_https_pg17_isolated.sh; then
  mark REAL_HTTPS_PG17_FLUTTER PASS
else
  mark REAL_HTTPS_PG17_FLUTTER FAIL
  mark RESULT 4
  exit 4
fi
mark PUBLIC_OPERATIONAL_ENDPOINT_ENABLED NO
mark RESULT 0
