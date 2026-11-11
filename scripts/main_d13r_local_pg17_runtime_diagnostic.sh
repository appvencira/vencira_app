#!/usr/bin/env bash
# D13-R: isolate D4-C failure without downloading the D12 remote tar again.
# Reuses local archive that already matched the restored D12 archive SHA-256.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf 'D13R_%s=%s\n' "$1" "$2"; }
echo MFA_RELEASE_AUTHORIZED=NO
echo NO_DEPLOY_NO_LIVE_MIGRATION=1
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
mark REMOTE_RESTIC_DOWNLOAD_EXECUTED NO
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_ONLY FAIL; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
head="$(git rev-parse --verify HEAD 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
remote="$(git rev-parse --verify refs/remotes/origin/main 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
status="$(git status --porcelain 2>/dev/null)" || { mark MAIN_CLEAN FAIL; exit 2; }
[[ "$head" == "$remote" && -z "$status" ]] || { mark MAIN_CLEAN FAIL; exit 2; }
mark MAIN_CLEAN PASS
archive="/home/vencira/vencira-release-archives/pre-upgrade-82d5a9324f6141b67b5b55a7"
[[ -d "$archive" && ! -L "$archive" ]] || { mark LOCAL_ARCHIVE_MISSING YES; exit 3; }
(cd "$archive" && sha256sum --status -c images.tar.gz.sha256) || { mark LOCAL_ARCHIVE_CHECKSUM FAIL; exit 3; }
mark LOCAL_ARCHIVE_CHECKSUM PASS
runner="$root/scripts/main_d4c_pg17_archived_isolated_runtime.sh"
[[ -f "$runner" && ! -L "$runner" ]] || { mark RUNTIME_SCRIPT_MISSING YES; exit 3; }
bash -n "$runner" || { mark RUNTIME_SYNTAX FAIL; exit 3; }
work="$(mktemp -d /tmp/vencira-d13r.XXXXXXXX)"
chmod 700 "$work"
cleanup(){
  local rc=$?
  trap - EXIT
  rm -f -- "$work/runtime.log" || rc=9
  rmdir "$work" || rc=9
  mark PRIVATE_LOG_REMOVED "$([[ "$rc" == 9 ]] && echo NO || echo YES)"
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
rc=0
bash "$runner" "$archive" >"$work/runtime.log" 2>&1 || rc=$?
python3 - "$work/runtime.log" "$rc" <<'PY'
import pathlib,re,sys
content=pathlib.Path(sys.argv[1]).read_text(errors="replace")
keys=("MAIN_SYNC","ARCHIVE_CHECKSUM","STORAGE_CAPACITY","XDG_RUNTIME_DIRECTORY",
      "ROOTLESS_RUNTIME_ENV","PODMAN_INFO_ERROR_CATEGORY","PODMAN_INFO_EXIT_CODE",
      "ROOTLESS_PODMAN_STORE","ROOTLESS_PRIVATE_STORE","ROOTLESS_IMAGE_IMPORT",
      "IMPORTED_IMAGE_COUNT_3","ARCHIVED_PG17_ROLE_IDENTITY","PG17_START",
      "PG17_READY","PG17_SYNTHETIC_SQL","EPHEMERAL_STORAGE_REMOVED","RESULT")
for key in keys:
    found=re.findall(r"(?m)^D4C_"+key+r"=([A-Za-z0-9_]+)$",content)
    if found: print("D13R_D4C_"+key+"="+found[-1],flush=True)
print("D13R_D4C_SHELL_EXIT="+sys.argv[2],flush=True)
PY
if [[ "$rc" != 0 ]]; then
  mark PG17_LOCAL_RUNTIME FAIL
  exit 5
fi
mark PG17_LOCAL_RUNTIME PASS
mark REMOTE_PG17_RUNTIME_IN_THIS_EXECUTION NO
mark ARCHIVE_CONFIG_ID_EQUIVALENCE_VERIFIED NO
exit 0
