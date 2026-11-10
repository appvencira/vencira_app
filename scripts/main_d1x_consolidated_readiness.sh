#!/usr/bin/env bash
# D1-X consolidated evidence: loaded Caddy metadata + isolated synthetic full-DB restore.
# Never modifies DEV services, persistent volumes or operational Caddy.
set -Eeuo pipefail
set +x
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
echo 'D1X_RELEASE_AUTHORIZED=NO'
echo 'D1X_DEPLOY_EXECUTED=NO'
echo 'D1X_LIVE_MIGRATIONS_EXECUTED=NO'
echo 'D1X_LIVE_RESTORE_EXECUTED=NO'
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for tool in git python3 bash openssl docker; do
  command -v "$tool" >/dev/null || { echo "D1X_REQUIRED_TOOL_MISSING=YES"; exit 2; }
done
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  echo 'D1X_MAIN_HEAD_REQUIRED=FAIL'; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { echo 'D1X_CLEAN_TREE_REQUIRED=FAIL'; exit 2; }
python3 - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d1x_loaded_caddy_readonly.py").read_text(encoding="utf-8"))
print("D1X_PYTHON_AST=PASS")
PY
bash -n scripts/main_d1x_consolidated_readiness.sh scripts/main_d1x_full_db_recovery_isolated.sh
echo 'D1X_BASH_SYNTAX=PASS'
caddy_rc=0
python3 scripts/main_d1x_loaded_caddy_readonly.py || caddy_rc=$?
if [[ "$caddy_rc" == 0 ]]; then
  echo 'D1X_CADDY_LOADED_CONFIG_GATE=PASS'
elif [[ "$caddy_rc" == 2 ]]; then
  echo 'D1X_CADDY_LOADED_CONFIG_GATE=NOT_VERIFIED'
else
  echo 'D1X_CADDY_LOADED_CONFIG_GATE=FAIL'
fi
bash scripts/main_d1x_full_db_recovery_isolated.sh || {
  echo 'D1X_SYNTHETIC_FULL_DB_GATE=FAIL'
  exit 6
}
echo 'D1X_SYNTHETIC_FULL_DB_GATE=PASS'
echo 'D1X_BROWSER_VISUAL_VERIFIED=NO'
echo 'D1X_OPERATIONAL_ROLLBACK_VERIFIED=NO'
if [[ "$caddy_rc" != 0 ]]; then
  echo 'D1X_RESULT=2'
  exit 2
fi
echo 'D1X_METADATA_AND_SYNTHETIC_RESTORE_GATE=PASS'
echo 'D1X_RESULT=0'
