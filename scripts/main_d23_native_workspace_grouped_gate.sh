#!/usr/bin/env bash
# D23: isolated live membership/assignment authorization and D20-D22 regression.
set -Eeuo pipefail
set +x
umask 077
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
echo "D23_DEPLOY_EXECUTED=NO"
echo "D23_LIVE_MIGRATIONS_EXECUTED=NO"
echo "D23_PUBLIC_WORKSPACE_ROUTE_ENABLED=NO"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "D23_RESULT=$1"; exit "$1"; }
[[ "$(id -u)" != 0 ]] || fail 2
HEAD="$(git rev-parse HEAD)" || fail 2
MAIN="$(git rev-parse refs/remotes/origin/main)" || fail 2
[[ "$HEAD" == "$MAIN" && -z "$(git status --porcelain)" ]] || fail 2
echo "D23_MAIN_CLEAN=PASS"
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh || fail 2
python3 scripts/main_d18_native_auth_release_fence_static.py || fail 3
echo "D23_OPERATIONAL_ROUTE_FENCE=PASS"
bash scripts/native_i8k_recovery_http_pg17_isolated.sh || fail 4
echo "D23_WORKSPACE_ASSIGNMENT_PG17=PASS"
echo "D23_OPERATIONAL_ISSUER_ENABLED=NO"
echo "D23_RESULT=0"
