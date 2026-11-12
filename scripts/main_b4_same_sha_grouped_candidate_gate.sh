#!/usr/bin/env bash
# B4: one SHA, one backend PG17 regression, one Flutter Android+Web build.
# Not a production release decision, deployment, signing or live restore.
set -Eeuo pipefail
set +x
umask 077
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
echo B4_DEPLOY_EXECUTED=NO
echo B4_LIVE_MIGRATIONS_EXECUTED=NO
echo B4_LIVE_RESTORE_EXECUTED=NO
echo B4_PRODUCTION_RELEASE_AUTHORIZED=NO

[[ "$(id -u)" != 0 ]] || { echo B4_NONROOT_REQUIRED=FAIL; exit 2; }
for c in git docker sudo python3 sha256sum; do
  command -v "$c" >/dev/null || { echo "B4_MISSING_TOOL=$c"; exit 2; }
done
head="$(git rev-parse --verify HEAD)"
remote="$(git rev-parse --verify refs/remotes/origin/main)"
if [[ "$(git branch --show-current)" != main || "$head" != "$remote" ||
      -n "$(git status --porcelain)" ]]; then
  echo B4_MAIN_CLEAN=FAIL; exit 2
fi
echo "B4_CANDIDATE_SHA=$head"
echo B4_MAIN_CLEAN=PASS
for file in \
  scripts/native_i8k_recovery_http_pg17_isolated.sh \
  scripts/main_b4_android_web_same_sha_candidate_gate.sh \
  scripts/main_joint_web_android_release_readiness_readonly.sh; do
  test -f "$file" && test ! -L "$file"
  bash -n "$file"
done
echo B4_SHELL_PREFLIGHT=PASS
stage=PRECHECK
on_exit() {
  local rc=$?
  trap - EXIT
  if (( rc == 0 )); then
    echo B4_SAME_SHA_REGRESSION=PASS
  else
    echo "B4_FAILED_STAGE=$stage"
  fi
  echo "B4_RESULT=$rc"
  echo MFA_RELEASE_AUTHORIZED=NO
  echo NO_DEPLOY_NO_LIVE_MIGRATION=1
  exit "$rc"
}
trap on_exit EXIT

# Read-only production-auth guard: 0 means DENIED, never released.
stage=PRODUCTION_FENCES
bash scripts/main_joint_web_android_release_readiness_readonly.sh
echo B4_PRODUCTION_AUTH_FENCED=PASS

# Covers independent D27 + legacy API/MFA security contracts in one
# disposable PG17 test database, no Android physical session.
stage=BACKEND_PG17
bash scripts/native_i8k_recovery_http_pg17_isolated.sh
echo B4_DJANGO_PG17_HTTP_SECURITY=PASS

# Flutter analyze, four core auth client suites, Android DEBUG + Web
# RELEASE-static from the same checkout and one SDK container.
stage=FLUTTER_WEB_ANDROID
bash scripts/main_b4_android_web_same_sha_candidate_gate.sh
echo B4_FLUTTER_WEB_ANDROID_BUILD=PASS
echo B4_ANDROID_RELEASE_SIGNING_VERIFIED=NO
echo B4_WEB_PUBLIC_HTTPS_VERIFIED=NO
echo B4_FUNCTIONAL_UI_E2E_VERIFIED=NO
