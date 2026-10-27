#!/usr/bin/env bash
# VENCIRA MFA: entrada de preflight separada, read-only y fail-closed.
# Este script NO despliega, NO migra y NO autoriza ninguna operacion.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
fail() { echo "MFA_DEPLOY_ENTRY=BLOCKED"; echo "REASON=$1"; echo "NO_DEPLOY_NO_MIGRATION=1"; exit 4; }
test "$#" -eq 1 || fail EXACT_CANDIDATE_REQUIRED
candidate="$(git rev-parse --verify "$1^{commit}" 2>/dev/null)" || fail UNKNOWN_CANDIDATE
test "$(git branch --show-current)" = integration/local-e2e-prep || fail WRONG_BRANCH
test "$(git rev-parse HEAD)" = "$candidate" || fail WRONG_CHECKOUT
test -z "$(git diff --name-only)" || fail DIRTY_TREE
test -z "$(git diff --cached --name-only)" || fail DIRTY_INDEX
# Fallo cerrado hasta que el control de esquema real, la custodia y la
# recuperacion sin factores sean integrados y acreditados.
set +e
bash scripts/mfa_s1_release_readonly.sh "$candidate"
guard_rc=$?
set -e
test "$guard_rc" -eq 4 || fail UNEXPECTED_GUARD_EXIT
echo "MFA_DEPLOY_ENTRY_PREFLIGHT=OK"
echo "MFA_RUNTIME_SCHEMA=PENDING"
echo "MFA_EXTERNAL_CUSTODY=PENDING"
echo "MFA_LOST_FACTOR_RECOVERY=PENDING"
fail RELEASE_NOT_AUTHORIZED
