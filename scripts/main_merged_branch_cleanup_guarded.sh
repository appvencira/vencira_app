#!/usr/bin/env bash
# VENCIRA: audited remote-branch cleanup, DEFAULT = DRY RUN.
# Applies only to 15 integration PRs (#19-#33) confirmed merged into main
# on 2026-11-08. Does not change local refs/worktrees, databases or containers.
set -Eeuo pipefail

mode="${1:---dry-run}"
if [[ "$mode" != "--dry-run" && "$mode" != "--apply" ]]; then
  echo "USAGE: bash scripts/main_merged_branch_cleanup_guarded.sh [--dry-run|--apply]" >&2
  exit 2
fi
cd "$(dirname "${BASH_SOURCE[0]}")/.."
test "$(git remote get-url origin | sed -E 's#^(git@github.com:|https://github.com/)##; s#\.git$##')" = "appvencira/vencira_app" || {
  echo "CLEANUP_REPO_MISMATCH=DENIED"; exit 3;
}
test -z "$(git status --porcelain)" || { echo "CLEANUP_DIRTY_WORKTREE=DENIED"; exit 4; }
test "$(git rev-parse refs/remotes/origin/main)" = "$(git rev-parse HEAD)" || {
  echo "CLEANUP_MAIN_NOT_CHECKED_OUT_AT_ORIGIN=DENIED"; exit 5;
}
for command in git; do command -v "$command" >/dev/null; done

branches=(
 integration/i1-calendar-core-20261106
 integration/i2-main-foundation-gate-20261106
 integration/i2b-django-bootstrap-20261106
 integration/i2b2-reminders-backend-20261106
 integration/i2c-flutter-client-20261106
 integration/i2d-c-ficha-isolated-20261106
 integration/i2e-native-security-labs-20261106
 integration/i3-integral-main-gates-20261106
 integration/i4-https-lab-20261106
 integration/i5-browser-android-20261106
 integration/i6-android-emulator-20261106
 integration/i7a-native-issuance-security-contract-20261106
 integration/i7b-mfa-atomic-candidate-20261106
 integration/main-web-attachments-failclosed-20261107
 integration/native-auth-lab-gates-20261107
)

echo "BRANCH_CLEANUP_MODE=$mode"
echo "BRANCH_CLEANUP_BASE=$(git rev-parse HEAD)"
echo "BRANCH_CLEANUP_MERGED_PRS=19-33 (verified on 2026-11-08)"
echo "BRANCH_CLEANUP_COUNT=${#branches[@]}"
echo "No historical feature branches or open-PR heads are in this list."
echo "No local directories or worktrees are modified."

deleted=0; skipped=0
for branch in "${branches[@]}"; do
  remote_ref="refs/heads/$branch"
  remote_sha="$(git ls-remote --exit-code origin "$remote_ref" | awk '{print $1}')" || {
    echo "SKIP_NOT_FOUND=$branch"
    ((skipped+=1))
    continue
  }
  if [[ ! "$remote_sha" =~ ^[0-9a-f]{40}$ ]]; then
    echo "CLEANUP_INVALID_REMOTE_SHA=$branch" >&2; exit 6
  fi
  # Fetch only this branch by object, without rewriting local refs.
  git cat-file -e "$remote_sha^{commit}" 2>/dev/null || {
    echo "CLEANUP_REMOTE_OBJECT_MISSING_LOCALLY=$branch" >&2
    echo "Fetch remote refs before rerunning cleanup." >&2
    exit 7
  }
  # Reject if the branch has any file path that main does not have.
  if git diff --name-only --diff-filter=A HEAD "$remote_sha" -- | grep -q .; then
    echo "SKIP_UNIQUE_FILES=$branch"
    ((skipped+=1))
    continue
  fi
  # Reject if any still-open local branch checkout points to this exact name.
  if git worktree list --porcelain | grep -Fxq "branch refs/heads/$branch"; then
    echo "SKIP_LOCAL_WORKTREE=$branch"
    ((skipped+=1))
    continue
  fi
  echo "ELIGIBLE=$branch SHA=$remote_sha"
  if [[ "$mode" == "--apply" ]]; then
    # Delete only if the remote still points at the checked exact SHA.
    git push --porcelain "--force-with-lease=$remote_ref:$remote_sha" origin ":$remote_ref"
    echo "DELETED_REMOTE_BRANCH=$branch"
    ((deleted+=1))
  fi
done
echo "BRANCH_CLEANUP_DELETED=$deleted"
echo "BRANCH_CLEANUP_SKIPPED=$skipped"
echo "BRANCH_CLEANUP_DONE=YES"
