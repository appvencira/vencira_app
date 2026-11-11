#!/usr/bin/env bash
# D3 grouped release readiness: one execution, no operational changes.
# The only destructive actions are inside a newly created PG17 tmpfs lab.
set -Eeuo pipefail
set +x
mark(){ printf 'D3_%s=%s\n' "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
[[ "$(git branch --show-current)" == main ]] || { mark MAIN_REQUIRED FAIL; exit 2; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || {
  mark MAIN_SYNC FAIL; exit 2;
}
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE FAIL; exit 2; }
mark MAIN_SYNC PASS
# Fast preflight: syntax/fixture API contract before costly Docker operations.
bash -n scripts/main_d3a_full_pg17_rollback_isolated.sh
python3 - <<'PY'
import ast
from pathlib import Path
ast.parse(Path("scripts/main_d2e_seed_synthetic.py").read_text())
print("D3_FIXTURE_SYNTAX=PASS")
PY
mark SHELL_AND_FIXTURE_SYNTAX PASS
# One grouped lab, not a replay of the already-closed D1-Z/D2-D/D2-E tests.
bash scripts/main_d3a_full_pg17_rollback_isolated.sh
mark D3A_FULL_DATABASE_ROLLBACK_PASS YES
# Release blocker inventory: do not claim an operational rollback or Caddy
# configuration assessment from an ephemeral PG17 experiment.
mark FULL_SYNTHETIC_DATABASE_RECOVERY PASS
mark OPERATIONAL_IMAGE_AND_PERSISTENT_DB_ROLLBACK_VERIFIED NO
mark PRODUCTION_CADDY_CONFIG_VERIFIED NO
mark MFA_RELEASE_AUTHORIZED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RELEASE_READINESS GATED
mark RESULT 0
