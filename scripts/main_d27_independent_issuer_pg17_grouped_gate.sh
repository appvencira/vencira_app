#!/usr/bin/env bash
# D27 phase-2 independent transactional password/MFA/session core: PG17 only.
# It does not activate an operational issuer or register public routes.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D27_P2_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark PRODUCTION_ISSUER_ENABLED NO
mark ANDROID_MAIN_AUTH_ENABLED NO
trap 'exit 130' INT
trap 'exit 143' TERM
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(id -u)" != 0 ]] || { mark RESULT 2; exit 2; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" &&
  -z "$(git status --porcelain)" ]] || {
  mark MAIN_CLEAN FAIL
  mark RESULT 2
  exit 2
}
mark MAIN_CLEAN PASS
python3 -B - <<'PY'
import ast
from pathlib import Path
core=Path("backend/native_mobile_service/native_operational_issuer_core.py")
test=Path("backend/native_mobile_service/test_d27_operational_core_pg17.py")
for path in (core, test):
    ast.parse(path.read_text(), filename=str(path))
source=core.read_text()
for forbidden in ("candidate_two_step_issuer", "candidate_recovery_issuer",
                  "candidate_challenge_store", "session_store", "test_d22_http_views"):
    assert forbidden not in source.split("\nfrom ", 1)[-1].split("\nclass ", 1)[0], forbidden
assert 'settings.VENCIRA_ENV == "test"' in source
assert 'not settings.VENCIRA_NATIVE_BEARER_ENABLED' in source
print("D27_P2_INDEPENDENT_AST_AND_LAB_FENCE=PASS")
PY
mark SOURCE_GATE PASS
if bash scripts/main_d27d28_grouped_contract_gate.sh; then
  mark RELEASE_BARRIERS PASS
else
  mark RELEASE_BARRIERS FAIL
  mark RESULT 3
  exit 3
fi
if bash scripts/native_i8k_recovery_http_pg17_isolated.sh; then
  mark PG17_ISSUER_AND_SECURITY PASS
else
  mark PG17_ISSUER_AND_SECURITY FAIL
  mark RESULT 4
  exit 4
fi
mark PRODUCTION_ISSUER_ENABLED NO
mark ANDROID_MAIN_AUTH_ENABLED NO
mark INDEPENDENT_CORE_VALIDATED YES
mark RESULT 0
