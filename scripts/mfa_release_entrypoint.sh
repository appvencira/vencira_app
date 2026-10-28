#!/usr/bin/env bash
# Canonical future MFA release entrypoint. Intentionally pre-authorization ONLY.
# No deployment, DB write, key installation, or flag activation.
set -Eeuo pipefail
umask 077
cd /home/vencira/vencira-localcheck
block() {
  echo "MFA_UNIFIED_RELEASE=BLOCKED"
  echo "REASON=$1"
  echo "MFA_RELEASE_AUTHORIZED=NO"
  echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
  exit 4
}
test "$#" -eq 2 || block USAGE_STAGE_AND_COMMIT_REQUIRED
stage="$1"
case "$stage" in schema-off|mfa-enable|rollback) ;; *) block INVALID_STAGE ;; esac
candidate="$(git rev-parse --verify "$2^{commit}" 2>/dev/null)" || block INVALID_CANDIDATE
test "$(git branch --show-current)" = integration/local-e2e-prep || block WRONG_BRANCH
test "$(git rev-parse HEAD)" = "$candidate" || block CANDIDATE_MISMATCH
test -z "$(git diff --name-only)" || block DIRTY_WORKTREE
test -z "$(git diff --cached --name-only)" || block DIRTY_INDEX
test -z "$(git ls-files --others --exclude-standard | grep -vx 'clients/flutter/pubspec.lock' || true)" || block UNTRACKED_FILES
# All three stages deliberately blocked. Never treat a synthetic test result,
# environment variable, or historical deploy confirmation as approval.
echo "MFA_RELEASE_STAGE=$stage"
block "OPERATIONAL_AUTHORIZATION_REQUIRED"
