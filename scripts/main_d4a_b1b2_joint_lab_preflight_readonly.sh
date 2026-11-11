#!/usr/bin/env bash
# D4-A: single non-destructive preflight for combined B1/B2 image + O5 recovery lab.
# Verifies lab prerequisites only. No Docker image load, run, restic read,
# database access, container execution, deployment or filesystem modification.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D4A_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
for k in RELEASE_AUTHORIZED DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED CONTAINER_RUN_EXECUTED OPERATIONAL_ROLLBACK_EXECUTED; do
  mark "$k" NO
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_OPERATOR FAIL; mark RESULT 2; exit 2; }
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || { mark MAIN_SYNC FAIL; mark RESULT 2; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE FAIL; mark RESULT 2; exit 2; }
mark MAIN_SYNC PASS
for t in podman python3 stat id systemctl; do
  command -v "$t" >/dev/null 2>&1 || { mark "MISSING_TOOL" "$t"; mark RESULT 3; exit 3; }
done
mark LAB_PREREQUISITES PASS
archive_root="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
if [[ -d "$archive_root" && ! -L "$archive_root" && "$(stat -c '%u:%a' "$archive_root")" == "$(id -u):700" ]]; then
  mark PRIVATE_ARCHIVE_DIRECTORY PASS
else
  mark PRIVATE_ARCHIVE_DIRECTORY FAIL; mark RESULT 4; exit 4
fi
for f in images.tar.gz images.tar.gz.sha256 images.manifest; do
  file="$archive_root/$f"
  if [[ ! -f "$file" || -L "$file" || "$(stat -c '%u:%a' "$file")" != "$(id -u):600" ]]; then
    mark PRIVATE_ARCHIVE_FILES FAIL
    mark RESULT 4
    exit 4
  fi
done
mark PRIVATE_ARCHIVE_FILES PASS
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" && ! -L "$XDG_RUNTIME_DIR" && "$(stat -c %u "$XDG_RUNTIME_DIR")" == "$(id -u)" ]]; then
  mark XDG_RUNTIME PASS
else
  mark XDG_RUNTIME FAIL; mark RESULT 4; exit 4
fi
if podman info --format json >/dev/null 2>&1 && podman unshare true >/dev/null 2>&1; then
  mark PODMAN_ROOTLESS_ENV PASS
else
  mark PODMAN_ROOTLESS_ENV FAIL; mark RESULT 4; exit 4
fi
if [[ -f scripts/main_d1n_o5_historical_migrations_pg17.sh && -f docs/operations/D3B5_ROOTLESS_IMAGE_IMPORT_PASS_2026-11-11.md && -f docs/operations/D3B6C_OCI_BLOB_SHA256_PASS_2026-11-11.md ]]; then
  mark IMAGE_AND_O5_HISTORICAL_LAB_PROCEDURES PRESENT
else
  mark IMAGE_AND_O5_HISTORICAL_LAB_PROCEDURES MISSING; mark RESULT 4; exit 4
fi
# Do not source or print encrypted backup settings; only verify the contract files
# exist, are owned by root, and their permissions are restrictive.
if sudo -n test -d /etc/vencira-backup &&
   sudo -n test -f /etc/vencira-backup/config.env &&
   sudo -n test -f /etc/vencira-backup/restic-password &&
   sudo -n test -f /etc/vencira-backup/rclone.conf &&
   sudo -n test "$(sudo -n stat -c '%u:%a' /etc/vencira-backup)" = '0:700' &&
   sudo -n test "$(sudo -n stat -c '%u:%a' /etc/vencira-backup/config.env)" = '0:600' &&
   sudo -n test "$(sudo -n stat -c '%u:%a' /etc/vencira-backup/restic-password)" = '0:600' &&
   sudo -n test "$(sudo -n stat -c '%u:%a' /etc/vencira-backup/rclone.conf)" = '0:600'; then
  mark O5_CREDENTIAL_PATH_PERMISSIONS PASS
else
  mark O5_CREDENTIAL_PATH_PERMISSIONS UNVERIFIED
fi
if systemctl is-active --quiet docker; then
  mark HOST_DOCKER_SERVICE ACTIVE
else
  mark HOST_DOCKER_SERVICE NOT_ACTIVE
fi
mark ISOLATED_RUNTIME_EXECUTED NO
mark REAL_O5_IN_SAME_LAB_RESTORED NO
mark B1_EXECUTABLE_RECOVERY_VERIFIED NO
mark B2_IMAGE_O5_COMPATIBILITY_VERIFIED NO
mark OFF_HOST_COPY_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
mark PUBLIC_RELEASE_AUTHORIZED NO
mark LAB_PREFLIGHT PASS
mark RESULT 0
