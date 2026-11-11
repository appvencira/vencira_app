#!/usr/bin/env bash
# D22 grouped native HTTP issuer security lab. No operational URL or deploy.
set -Eeuo pipefail
set +x
umask 077
printf 'MFA_RELEASE_AUTHORIZED=NO\nNO_DEPLOY_NO_LIVE_MIGRATION=1\n'
printf 'D22_DEPLOY_EXECUTED=NO\nD22_LIVE_MIGRATIONS_EXECUTED=NO\n'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf 'D22_RESULT=%s\n' "$1"; exit "$1"; }
[[ "$(id -u)" != 0 ]] || fail 2
HEAD="$(git rev-parse HEAD)" || fail 2
MAIN="$(git rev-parse refs/remotes/origin/main)" || fail 2
[[ "$HEAD" == "$MAIN" && -z "$(git status --porcelain)" ]] || fail 2
echo 'D22_MAIN_CLEAN=PASS'
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh || fail 2
python3 scripts/main_d18_native_auth_release_fence_static.py || fail 3
echo 'D22_PRODUCTION_ROUTE_FENCE=PASS'
bash scripts/native_i8k_recovery_http_pg17_isolated.sh || fail 4
echo 'D22_SERVER_CUSTODY_HTTP_PG17=PASS'
echo 'D22_OPERATIONAL_ISSUER_ENABLED=NO'
echo 'D22_WORKSPACE_AUTHORIZATION_GATE=NOT_VERIFIED'
echo 'D22_RESULT=0'
