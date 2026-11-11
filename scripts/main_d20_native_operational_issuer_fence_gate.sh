#!/usr/bin/env bash
# D20: single isolated PG17 candidate HTTP and operational-issuer fence gate.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D20_%s=%s\n' "$1" "$2"; }
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark RELEASE_AUTHORIZED NO
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
[[ "$(id -u)" != 0 ]] || { mark NONROOT_REQUIRED FAIL; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
head="$(git rev-parse HEAD)" || { mark MAIN_SYNC FAIL; exit 2; }
origin="$(git rev-parse refs/remotes/origin/main)" || { mark MAIN_SYNC FAIL; exit 2; }
[[ "$head" == "$origin" && -z "$(git status --porcelain)" ]] || {
  mark MAIN_SYNC FAIL
  exit 2
}
mark MAIN_SYNC PASS
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh
python3 scripts/main_d18_native_auth_release_fence_static.py
mark OPERATIONAL_ROUTING_FENCE PASS
rc=0
bash scripts/native_i8k_recovery_http_pg17_isolated.sh || rc=$?
if [[ "$rc" != 0 ]]; then
  mark PG17_ISSUER_POLICY FAIL
  mark RESULT "$rc"
  exit "$rc"
fi
mark PG17_ISSUER_POLICY PASS
mark CREDENTIAL_ISSUER_ENABLED NO
mark OPERATIONAL_ROUTES_ENABLED NO
mark RESULT 0
