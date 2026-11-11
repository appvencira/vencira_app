#!/usr/bin/env bash
# D13 grouped remote D12 snapshot recovery + PG17 synthetic runtime from it.
# No host Docker load, no production deployment and NO O5 data restore.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D13_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
for k in DEPLOY_EXECUTED LIVE_MIGRATIONS_EXECUTED LIVE_RESTORE_EXECUTED HOST_DOCKER_IMAGE_LOAD_EXECUTED CADDY_RELOAD_EXECUTED CADDY_CONFIG_CHANGED DNS_CHANGED OPERATIONAL_ROLLBACK_EXECUTED; do mark "$k" NO; done
mark CONTAINER_RUN_EXECUTED NO
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_WRAPPER_REQUIRED FAIL; exit 2; }
for t in git sudo podman python3 mktemp df sha256sum stat; do
  command -v "$t" >/dev/null 2>&1 || { mark PREREQUISITE_MISSING "$t"; exit 2; }
done
root="$(cd "$(dirname "$${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" &&
   -z "$(git status --porcelain)" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
helper="$root/scripts/main_d13_remote_image_archive_root_helper.sh"
runtime="$root/scripts/main_d4c_pg17_archived_isolated_runtime.sh"
for path in "$helper" "$runtime"; do
  [[ -f "$path" && ! -L "$path" ]] || { mark SCRIPT_MISSING FAIL; exit 2; }
  bash -n "$path" || { mark SYNTAX FAIL; exit 2; }
done
[[ -n "$${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" &&
   ! -L "$XDG_RUNTIME_DIR" &&
   "$(stat -c %u "$XDG_RUNTIME_DIR")" == "$(id -u)" ]] || {
  mark ROOTLESS_RUNTIME_PREREQUISITES FAIL; exit 3;
}
mark ROOTLESS_RUNTIME_PREREQUISITES PASS
workspace="$HOME/vencira-release-archives"
[[ "$workspace" == /home/vencira/vencira-release-archives &&
   -d "$workspace" && ! -L "$workspace" &&
   "$(stat -c '%u:%a' "$workspace")" == "$(id -u):700" ]] || {
  mark PRIVATE_WORKSPACE FAIL; exit 3;
}
source_archive="$workspace/pre-upgrade-82d5a9324f6141b67b5b55a7/images.tar.gz"
[[ -f "$source_archive" && ! -L "$source_archive" ]] || { mark SOURCE_ARCHIVE_SIZE_UNAVAILABLE FAIL; exit 3; }
bytes="$(stat -c %s "$source_archive")"
free_kib="$(df -Pk "$workspace" | awk 'END {print $4}')"
[[ "$bytes" =~ ^[0-9]+$ && "$free_kib" =~ ^[0-9]+$ ]] || { mark CAPACITY_CHECK FAIL; exit 3; }
# Need fresh remote tar PLUS rootless VFS import, plus 3 GiB cushion.
needed=$(((bytes*7+3221225472+1023)/1024))
(( free_kib >= needed )) || { mark CAPACITY_CHECK FAIL; exit 3; }
mark CAPACITY_CHECK PASS
sudo -n true >/dev/null 2>&1 || { mark SUDO_AUTHENTICATION_REQUIRED YES; exit 3; }
lab="$(mktemp -d "$workspace/d13-remote.XXXXXXXX")"
chmod 700 "$lab"
cleanup(){
  rc=$?
  trap - EXIT
  case "$lab" in "$workspace"/d13-remote.*) ;; *) mark CLEANUP_SCOPE FAIL; exit 9;; esac
  if [[ -d "$lab" && ! -L "$lab" ]]; then
    sudo -n rm -f -- "$lab/images.tar.gz" "$lab/images.tar.gz.sha256" "$lab/images.manifest" "$lab/runtime.out" || rc=9
    rmdir "$lab" >/dev/null 2>&1 || rc=9
  else
    rc=9
  fi
  mark RECOVERED_TAR_REMOVED "$([[ "$rc" == 9 ]] && echo NO || echo YES)"
  mark LIVE_RESTORE_EXECUTED NO
  mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
# Remote download is read-only in the Restic repo, into the single D13 temp dir.
sudo -n bash "$helper" "$lab" "$(id -u)" || { mark REMOTE_D12_REHYDRATION FAIL; exit 4; }
mark REMOTE_D12_REHYDRATION PASS
# The runtime script creates its own fresh rootless Podman VFS store.
# It imports all three archived images, then boots archived PG17 on synthetic
# tmpfs data, checks SQL, and tears down. No persistent PGDATA or DEV volume.
mark CONTAINER_RUN_EXECUTED ISOLATED_ROOTLESS_LAB_ONLY
if bash "$runtime" "$lab" >"$lab/runtime.out" 2>&1; then
  for required in 'D4C_ROOTLESS_IMAGE_IMPORT=PASS' 'D4C_IMPORTED_IMAGE_COUNT_3=PASS' 'D4C_PG17_READY=PASS' 'D4C_PG17_SYNTHETIC_SQL=PASS' 'D4C_EPHEMERAL_STORAGE_REMOVED=YES' 'D4C_RESULT=0'; do
    if ! grep -Fxq "$required" "$lab/runtime.out"; then
      mark PG17_REMOTE_ARCHIVE_RUNTIME FAIL
      exit 5
    fi
  done
  mark ROOTLESS_ARCHIVED_IMAGES_IMPORT PASS
  mark PG17_REMOTE_ARCHIVE_RUNTIME PASS
else
  mark PG17_REMOTE_ARCHIVE_RUNTIME FAIL
  # The runtime log intentionally remains private and is removed by trap.
  exit 5
fi
mark REMOTE_IMAGE_ARCHIVE_PG17_RECOVERY PASS
mark IMAGE_API_WEB_FROM_REMOTE_RUNTIME_VERIFIED NO
mark IMAGE_O5_HISTORICAL_DATA_COMPATIBILITY_VERIFIED NO
mark ARCHIVED_ORIGINAL_DOCKER_IMAGE_IDS_EQUAL NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
exit 0
