#!/usr/bin/env bash
# D4: combined pre-deployment checkpoint. READ ONLY, does not execute deployment.
# Groups the five outstanding release blockers into one operator-visible result.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D4_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
for k in RELEASE_AUTHORIZED DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED OPERATIONAL_ROLLBACK_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED CONTAINER_RUN_EXECUTED; do
  mark "$k" NO
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
for cmd in git python3 stat find systemctl; do
  command -v "$cmd" >/dev/null || { mark PREREQUISITE FAIL; mark RESULT 2; exit 2; }
done
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse refs/remotes/origin/main)" ]]; then
  mark MAIN_SYNC FAIL; mark RESULT 2; exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
  mark CLEAN_TREE FAIL; mark RESULT 2; exit 2
fi
mark MAIN_SYNC PASS
mark CLEAN_TREE PASS

archive_root="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
if [[ -d "$archive_root" && ! -L "$archive_root" &&
      -f "$archive_root/images.tar.gz" && ! -L "$archive_root/images.tar.gz" &&
      -f "$archive_root/images.manifest" && ! -L "$archive_root/images.manifest" &&
      -f "$archive_root/images.tar.gz.sha256" && ! -L "$archive_root/images.tar.gz.sha256" ]]; then
  mark B1_IMAGE_ARCHIVE_LOCAL PRESENT
else
  mark B1_IMAGE_ARCHIVE_LOCAL MISSING
fi
# Historical D3-B5 and D3-B6C pass records, not a fresh runtime verification.
if [[ -f docs/operations/D3B5_ROOTLESS_IMAGE_IMPORT_PASS_2026-11-11.md &&
      -f docs/operations/D3B6C_OCI_BLOB_SHA256_PASS_2026-11-11.md ]]; then
  mark B1_ISOLATED_IMPORT_AND_BLOB_EVIDENCE DOCUMENTED
else
  mark B1_ISOLATED_IMPORT_AND_BLOB_EVIDENCE INCOMPLETE
fi
mark B1_EXECUTABLE_IMAGE_DB_RECOVERY VERIFIED_NO

# O5 restore was verified in earlier isolated labs, but never coupled with
# the archived images. Do not read backup credentials or real customer data.
if [[ -f docs/D3B_PREVIOUS_IMAGES_AND_OPERATIONAL_ROLLBACK_2026-11-11.md ]]; then
  mark B2_BACKUP_RESTORE_HISTORY DOCUMENTED
else
  mark B2_BACKUP_RESTORE_HISTORY MISSING
fi
mark B2_IMAGE_PLUS_REAL_O5_COMPATIBILITY VERIFIED_NO
mark B2_ROLLBACK_SWITCH_AND_REVERSE VERIFIED_NO

# No read of restic/rclone secrets; an external copy must have independent
# destination evidence, integrity and recovery authorization.
mark B3_OFF_HOST_ENCRYPTED_IMAGE_COPY VERIFIED_NO
mark B3_OFF_HOST_RESTORE_VERIFIED NO

# Evidence exists for historical test gates, but the final candidate commit
# has not been re-tested as a unified build/release candidate.
if [[ -f docs/MAIN_BRANCH_AUDIT_2026-11-08.md ]]; then
  mark B4_HISTORICAL_REGRESSION_EVIDENCE DOCUMENTED
else
  mark B4_HISTORICAL_REGRESSION_EVIDENCE MISSING
fi
mark B4_FINAL_MAIN_DJANGO_FLUTTER_SECURITY_GATE VERIFIED_NO
mark B4_MFA_RELEASE_AUTHORIZED NO

# Do not infer production configuration from DEV Caddy success.
if systemctl is-active --quiet caddy; then
  mark B5_HOST_CADDY_SERVICE ACTIVE
else
  mark B5_HOST_CADDY_SERVICE NOT_ACTIVE
fi
mark B5_DEV_HTTPS_HISTORY DOCUMENTED
mark B5_PRODUCTION_DOMAIN_TLS_COOKIES_CSRF VERIFIED_NO
mark B5_PUBLIC_RELEASE_APPROVAL NO

mark D3B3_EXACT_IMAGE_ID_DISCREPANCY OPEN
mark BLOCKERS_OPEN 5
mark RELEASE_READINESS BLOCKED
mark PUBLIC_RELEASE_AUTHORIZED NO
mark RESULT 4
exit 4
