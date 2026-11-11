#!/usr/bin/env bash
# D5: single grouped candidate regression and release blocker checkpoint.
# Never deploy, load images, access O5 secrets, run live migrations or restore.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D5_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for k in RELEASE_AUTHORIZED DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED OPERATIONAL_ROLLBACK_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED REAL_O5_RESTORE_EXECUTED; do mark "$k" NO; done
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_OPERATOR FAIL; mark RESULT 2; exit 2; }
for t in git bash python3 sha256sum stat sudo docker; do
  command -v "$t" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$t"; mark RESULT 2; exit 2; }
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse refs/remotes/origin/main)" ||
      -n "$(git status --porcelain)" ]]; then
  mark MAIN_CLEAN FAIL
  mark RESULT 2
  exit 2
fi
mark MAIN_CLEAN PASS
archive="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
[[ -d "$archive" && ! -L "$archive" &&
   "$(stat -c '%u:%a' "$archive")" == "$(id -u):700" ]] || {
  mark ARCHIVE_ACCESS FAIL; mark RESULT 3; exit 3;
}
for file in images.tar.gz images.tar.gz.sha256 images.manifest; do
  [[ -f "$archive/$file" && ! -L "$archive/$file" &&
    "$(stat -c '%u:%a' "$archive/$file" | cut -d: -f1)" == "$(id -u)" ]] || {
    mark ARCHIVE_ACCESS FAIL; mark RESULT 3; exit 3;
  }
done
(cd "$archive" && sha256sum --status -c images.tar.gz.sha256) || {
  mark ARCHIVE_CHECKSUM FAIL; mark RESULT 3; exit 3;
}
mark ARCHIVE_CHECKSUM PASS
# Preflight the combined historical candidate gate; this is the ONLY expensive
# lab D5 will run. Prior D4-E/F/G/H and D1-N are not repeated.
bash -n scripts/main_d1o_candidate_integral_gate.sh || {
  mark CANDIDATE_SCRIPT_SYNTAX FAIL; mark RESULT 3; exit 3;
}
mark CANDIDATE_SCRIPT_SYNTAX PASS
sudo -n true >/dev/null 2>&1 || {
  mark SUDO_SESSION REQUIRED; mark RESULT 2; exit 2;
}
mark PREEXISTING_D4E_D4F_D4G_NOT_REPEATED YES
mark PREEXISTING_REAL_O5_RESTORE_NOT_REPEATED YES
mark CANDIDATE_REGRESSION_STARTED YES
# D1-O builds a disposable main Django image + internal-only synthetic PG17,
# executes Django HTTP/security/reminders and Flutter analyze/test/web build.
# Its own trap verifies all three DEV containers retain their original IDs.
if bash scripts/main_d1o_candidate_integral_gate.sh; then
  mark CANDIDATE_REGRESSION PASS
else
  status=$?
  mark CANDIDATE_REGRESSION FAIL
  mark CANDIDATE_REGRESSION_EXIT_CODE "$status"
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT 5
  exit 5
fi
mark B1_ARCHIVED_IMAGE_FUNCTIONAL_RUNTIME PARTIAL
mark B1_FULL_ARCHIVE_RESTORE_VERIFIED NO
mark B2_REAL_O5_RESTORE_WITH_HOST_IMAGES PARTIAL
mark B2_ARCHIVED_IMAGE_AND_O5_END_TO_END VERIFIED_NO
mark B3_OFF_HOST_ENCRYPTED_ARCHIVE_CUSTODY VERIFIED_NO
mark B4_MAIN_DJANGO_FLUTTER_SYNTHETIC_GATE PASS
mark B4_FINAL_ANDROID_NATIVE_RELEASE_GATE VERIFIED_NO
mark B5_PUBLIC_DOMAIN_TLS_CSRF_COOKIES VERIFIED_NO
mark D3B3_EXACT_ARCHIVE_IMAGE_ID_CONFLICT OPEN
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark BLOCKERS_OPEN 5
mark RELEASE_READINESS BLOCKED
mark RESULT 4
exit 4
