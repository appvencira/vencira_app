#!/usr/bin/env bash
# D1-U consolidated gate: confidential Compose static policy + isolated TLS.
# Does not deploy to DEV or touch its PostgreSQL volume.
set -Eeuo pipefail
set +x
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
echo 'D1U_RELEASE_AUTHORIZED=NO'
echo 'D1U_DEPLOY_EXECUTED=NO'
echo 'D1U_LIVE_MIGRATIONS_EXECUTED=NO'
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
git fetch --quiet origin refs/heads/main:refs/remotes/origin/main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || {
  echo 'D1U_MAIN_HEAD_REQUIRED=FAIL'; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || {
  echo 'D1U_CLEAN_TREE_REQUIRED=FAIL'; exit 2;
}
python3 - <<'PY'
import ast
from pathlib import Path
for name in ("scripts/main_d1u_https_candidate_lab.py", "scripts/main_d1u_compose_semantics_readonly.py"):
    ast.parse(Path(name).read_text(encoding="utf-8"), filename=name)
print("D1U_PYTHON_SYNTAX_PREFLIGHT=PASS")
PY
bash -n scripts/main_d1u_consolidated_gate.sh scripts/main_d1u_candidate_https_pg17_isolated.sh
echo "D1U_BASH_SYNTAX_PREFLIGHT=PASS"
python3 scripts/main_d1u_compose_semantics_readonly.py || {
  echo 'D1U_COMPOSE_SEMANTICS_GATE=FAIL'; exit 3;
}
echo 'D1U_COMPOSE_SEMANTICS_GATE=PASS'
bash scripts/main_d1u_candidate_https_pg17_isolated.sh || {
  echo 'D1U_CANDIDATE_TLS_GATE=FAIL'; exit 4;
}
echo 'D1U_CANDIDATE_TLS_GATE=PASS'
echo 'D1U_CADDY_CANDIDATE_VERIFIED=NO'
echo 'D1U_ROLLBACK_VERIFIED=NO'
echo 'D1U_RESULT=0'
