#!/usr/bin/env bash
# MFA release gate: read-only. Must be called by every future MFA deployment/rollback.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
fail(){ echo "MFA_RELEASE_GUARD=BLOCKED"; echo "REASON=$1"; exit 4; }
test "$(git branch --show-current)" = integration/local-e2e-prep || fail WRONG_BRANCH
test -z "$(git diff --name-only)" || fail DIRTY_TREE
test -z "$(git diff --cached --name-only)" || fail DIRTY_INDEX
test "$#" -eq 1 || fail CANDIDATE_SHA_REQUIRED
CANDIDATE="$1"
git cat-file -e "$CANDIDATE^{commit}" 2>/dev/null || fail UNKNOWN_CANDIDATE
CANDIDATE="$(git rev-parse "$CANDIDATE^{commit}")"
# Evaluate the candidate commit, NOT the current checkout.
for path in backend/reminders/mfa_middleware.py backend/reminders/mfa_challenge.py backend/reminders/login_security.py; do
  git cat-file -e "$CANDIDATE:$path" 2>/dev/null || fail CANDIDATE_LACKS_MFA_CODE
done
git show "$CANDIDATE:backend/reminders/mfa_middleware.py" | grep -Fq 'class RequireMfaSessionMiddleware' || fail NO_MFA_MIDDLEWARE
git show "$CANDIDATE:backend/config/settings.py" | grep -Fq 'reminders.mfa_middleware.RequireMfaSessionMiddleware' || fail MFA_NOT_IN_SETTINGS
git show "$CANDIDATE:backend/reminders/login_security.py" | grep -Fq 'UserMfaState.objects.filter' || fail LOGIN_MFA_NOT_ENFORCED
git show "$CANDIDATE:backend/reminders/mfa_challenge.py" | grep -Fq 'PENDING_KEY' || fail CHALLENGE_MISSING
# Static checks are necessary, NOT proof of runtime enforcement. The
# authoritative check on live schema and active accounts is still required.
echo "MFA_CANDIDATE_STATIC_CHECK=OK"
echo "MFA_CANDIDATE_SHA=$CANDIDATE"
echo "MFA_RUNTIME_DB_GUARD=PENDING"
echo "MFA_RELEASE_AUTHORIZED=NO"
