#!/usr/bin/env bash
# D1-Y: single read-only release gap review, no operational mutations.
set -Eeuo pipefail
set +x
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
echo 'D1Y_RELEASE_AUTHORIZED=NO'
echo 'D1Y_DEPLOY_EXECUTED=NO'
echo 'D1Y_LIVE_MIGRATIONS_EXECUTED=NO'
echo 'D1Y_LIVE_RESTORE_EXECUTED=NO'
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  echo 'D1Y_MAIN_HEAD_REQUIRED=FAIL'; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || {
  echo 'D1Y_CLEAN_TREE_REQUIRED=FAIL'; exit 2;
}
python3 - <<'PY'
import ast
from pathlib import Path
for name in ("scripts/main_d1y_caddy_dev_route_readonly.py",
             "scripts/main_d1y_rollback_artifacts_readonly.py"):
    ast.parse(Path(name).read_text(encoding="utf-8"), filename=name)
print("D1Y_SOURCE_AST=PASS")
PY
caddy_rc=0
python3 scripts/main_d1y_caddy_dev_route_readonly.py || caddy_rc=$?
if [[ "$caddy_rc" == 0 ]]; then
  echo 'D1Y_DEV_ROUTE_GATE=PASS'
elif [[ "$caddy_rc" == 2 ]]; then
  echo 'D1Y_DEV_ROUTE_GATE=NOT_VERIFIED'
else
  echo 'D1Y_DEV_ROUTE_GATE=FAIL'
fi
python3 scripts/main_d1y_rollback_artifacts_readonly.py || {
  echo 'D1Y_ROLLBACK_INVENTORY_GATE=FAIL'
  echo 'D1Y_RESULT=6'
  exit 6
}
echo 'D1Y_ROLLBACK_INVENTORY_GATE=PASS'
echo 'D1Y_BROWSER_VISUAL_VERIFIED=NO'
echo 'D1Y_OPS_ROLLBACK_VERIFIED=NO'
if [[ "$caddy_rc" != 0 ]]; then
  echo 'D1Y_RESULT=2'
  exit 2
fi
echo 'D1Y_READONLY_GATE=PASS'
echo 'D1Y_RESULT=0'
