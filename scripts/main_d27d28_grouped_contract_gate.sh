#!/usr/bin/env bash
# D27–D28 phase-0 grouped contract: source policy + mutation regressions only.
# PASS means release remains denied; does not mean issuer or Android ready.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D27D28_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark RELEASE_AUTHORIZED NO
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
if python3 -B -m unittest discover -s tests -p test_d27d28_operational_boundary_audit.py -v; then
  mark MUTATION_FENCES PASS
else
  mark MUTATION_FENCES FAIL
  mark RESULT 3
  exit 3
fi
if python3 -B scripts/main_d27d28_operational_boundary_audit.py; then
  mark CODE_AUDIT PASS
else
  mark CODE_AUDIT FAIL
  mark RESULT 4
  exit 4
fi
if python3 -B scripts/main_d18_native_auth_release_fence_static.py; then
  mark LEGACY_RELEASE_FENCE PASS
else
  mark LEGACY_RELEASE_FENCE FAIL
  mark RESULT 5
  exit 5
fi
mark OPERATIONAL_ISSUER_IMPLEMENTED NO
mark ANDROID_NATIVE_LOGIN_CONNECTED NO
mark PHASE0_CONTRACT PASS
mark RESULT 0
