#!/usr/bin/env bash
# D26: signed workspace cursor, live membership, and real TLS Flutter in one gate.
set -Eeuo pipefail
set +x
umask 077
trap 'exit 130' INT
trap 'exit 143' TERM
mark(){ printf 'D26_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark AUTH_PRODUCTION_ENABLED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
if [[ "$(id -u)" == 0 ]]; then mark RESULT 2; exit 2; fi
head="$(git rev-parse --verify HEAD)" || { mark RESULT 2; exit 2; }
main="$(git rev-parse --verify refs/remotes/origin/main)" || { mark RESULT 2; exit 2; }
if [[ "$head" != "$main" || -n "$(git status --porcelain)" ]]; then
  mark MAIN_CLEAN FAIL
  mark RESULT 2
  exit 2
fi
mark MAIN_CLEAN PASS
bash -n scripts/native_i8k_recovery_http_pg17_isolated.sh || exit 2
bash -n scripts/main_d25_native_workspace_real_https_pg17_isolated.sh || exit 2
python3 -c 'import ast,pathlib; [ast.parse(pathlib.Path(p).read_text(), filename=p) for p in ("backend/native_mobile_service/native_workspace_cursor.py","backend/native_mobile_service/test_d22_http_views.py","backend/native_mobile_service/test_d26_workspace_cursor_pg17.py","scripts/native_i8k_https_server.py")]' || {
  mark PYTHON_AST FAIL
  mark RESULT 2
  exit 2
}
mark PYTHON_AST PASS
python3 scripts/main_d18_native_auth_release_fence_static.py || {
  mark RELEASE_FENCE FAIL
  mark RESULT 3
  exit 3
}
mark RELEASE_FENCE PASS
if bash scripts/native_i8k_recovery_http_pg17_isolated.sh; then
  mark CURSOR_PG17_SECURITY PASS
else
  mark CURSOR_PG17_SECURITY FAIL
  mark RESULT 4
  exit 4
fi
if bash scripts/main_d25_native_workspace_real_https_pg17_isolated.sh; then
  mark CURSOR_REAL_TLS_FLUTTER PASS
else
  mark CURSOR_REAL_TLS_FLUTTER FAIL
  mark RESULT 5
  exit 5
fi
mark PUBLIC_CURSOR_ENDPOINT_ENABLED NO
mark AUTH_PRODUCTION_ENABLED NO
mark RESULT 0
