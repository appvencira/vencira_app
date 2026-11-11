#!/usr/bin/env bash
# D3-B5: import archived Docker images into a fresh, separate ROOTLESS Podman
# vfs image store. No host Docker socket, root, sudo, containers, or PGDATA.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf "D3B5_%s=%s\n" "$1" "$2"; }
echo "MFA_RELEASE_AUTHORIZED=NO"
echo "NO_DEPLOY_NO_LIVE_MIGRATION=1"
mark RELEASE_AUTHORIZED NO
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark OPERATIONAL_ROLLBACK_EXECUTED NO
mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
mark CONTAINER_RUN_EXECUTED NO
[[ "$(id -u)" != 0 ]] || { mark ROOTLESS_REQUIRED FAIL; exit 2; }
for tool in git python3 sha256sum df mktemp podman; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    mark PREREQUISITE_MISSING "$tool"
    mark RESULT 4
    exit 4
  fi
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
[[ "$(git rev-parse HEAD)" == "$(git rev-parse refs/remotes/origin/main)" ]] || { mark MAIN_SYNC FAIL; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { mark CLEAN_TREE FAIL; exit 2; }
mark MAIN_SYNC PASS
archive_root="${1:-}"
[[ "$archive_root" == /* && -d "$archive_root" && ! -L "$archive_root" ]] || { mark ARCHIVE_PATH FAIL; exit 2; }
archive="$archive_root/images.tar.gz"
[[ -f "$archive" && ! -L "$archive" ]] || { mark ARCHIVE_FILE FAIL; exit 2; }
[[ "$(stat -c %u "$archive_root")" == "$(id -u)" ]] || { mark ARCHIVE_OWNERSHIP FAIL; exit 2; }
(cd "$archive_root" && sha256sum --status -c images.tar.gz.sha256) || { mark ARCHIVE_CHECKSUM FAIL; exit 3; }
mark ARCHIVE_CHECKSUM PASS
# Never let container clients pick up a remote socket from the operator shell.
unset CONTAINER_HOST DOCKER_HOST PODMAN_HOST
# Isolated vfs store can multiply disk usage; fail closed if insufficient.
archive_bytes="$(stat -c %s "$archive")"
[[ "$archive_bytes" =~ ^[0-9]+$ ]] || { mark ARCHIVE_SIZE FAIL; exit 3; }
workspace="$HOME/vencira-release-archives"
[[ -d "$workspace" && ! -L "$workspace" && "$(stat -c %u:%a "$workspace")" == "$(id -u):700" ]] || { mark PRIVATE_WORKSPACE FAIL; exit 3; }
free_kib="$(df -Pk "$workspace" | awk 'END {print $4}')"
[[ "$free_kib" =~ ^[0-9]+$ ]] || { mark STORAGE_CAPACITY FAIL; exit 3; }
# 6x compressed size + 3 GiB headroom: conservative but not absolute.
needed_kib=$(((archive_bytes*6+3221225472+1023)/1024))
(( free_kib >= needed_kib )) || { mark STORAGE_CAPACITY FAIL; mark RESULT 4; exit 4; }
mark STORAGE_CAPACITY PASS
lab="$(mktemp -d "$workspace/d3b5-rootless.XXXXXXXX")"
chmod 700 "$lab"
finished=NO
cleanup(){
  rc=$?
  trap - EXIT
  case "$lab" in "$workspace"/d3b5-rootless.*) ;; *) mark CLEANUP_PATH FAIL; exit 9;; esac
  if [[ -d "$lab" && ! -L "$lab" ]]; then
    rm -rf -- "$lab" || rc=9
  else
    rc=9
  fi
  mark EPHEMERAL_STORAGE_REMOVED "$([[ "$rc" == 9 ]] && echo NO || echo YES)"
  mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
  mark CONTAINER_RUN_EXECUTED NO
  mark OPERATIONAL_ROLLBACK_VERIFIED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
trap cleanup EXIT
mkdir -m 700 "$lab/graph" "$lab/run" "$lab/tmp" "$lab/home"
# Explicit per-command local rootless Podman; never fallback to Docker or sudo.
export HOME="$lab/home" XDG_CONFIG_HOME="$lab/home" TMPDIR="$lab/tmp"
P=(podman --remote=false --root "$lab/graph" --runroot "$lab/run" --storage-driver vfs --events-backend=file)
if "${P[@]}" info --format json >"$lab/info.json" 2>"$lab/error.log"; then
  :
else
  status=$?
  # Never print raw stderr: paths, environment details or runtime internals
  # can be sensitive. Emit only predefined error categories and exit status.
  python3 - "$lab/error.log" "$status" <<'PY'
import pathlib, re, sys
try:
    msg = pathlib.Path(sys.argv[1]).read_text(errors="replace").lower()
except OSError:
    msg = ""
rules = [
    ("UNKNOWN_FLAG", r"unknown flag|unknown shorthand flag|unknown option"),
    ("STORAGE_DRIVER_CONFLICT", r"database.*(graph driver|storage driver)|graph driver.*(mismatch|not match|different)"),
    ("NAMESPACE_FAILURE", r"cannot clone|unshare|user namespace|userns|newuidmap|newgidmap|cannot re-exec"),
    ("PERMISSION_FAILURE", r"permission denied|operation not permitted|access denied"),
    ("RUNTIME_DIRECTORY_FAILURE", r"xdg_runtime_dir|runroot|runtime directory|rootless storage"),
    ("STORAGE_CONFIGURATION_FAILURE", r"storage.conf|graphroot|graph root|storage driver|graphdriver"),
    ("DATABASE_FAILURE", r"database|bolt|sqlite"),
]
category = next((label for label, regex in rules if re.search(regex, msg)), "UNCLASSIFIED")
print("D3B5_PODMAN_INFO_ERROR_CATEGORY=" + category)
print("D3B5_PODMAN_INFO_EXIT_CODE=" + sys.argv[2])
PY
  mark ROOTLESS_PODMAN_STORE FAIL
  exit 4
fi
python3 - "$lab/info.json" "$lab/graph" <<'PY' || { mark STORAGE_ISOLATION FAIL; exit 4; }
import json, pathlib, sys
info=json.loads(pathlib.Path(sys.argv[1]).read_text())
store=info.get("store") or info.get("Store") or {}
graph=store.get("graphRoot") or store.get("GraphRoot")
expected=str(pathlib.Path(sys.argv[2]).resolve())
if not graph or str(pathlib.Path(graph).resolve()) != expected:
    raise SystemExit(1)
PY
mark ROOTLESS_PRIVATE_STORE PASS
mark HOST_DOCKER_SOCKET_MOUNTED NO
# Import archive into this unique store only; never run any image or attach a
# volume. Do not print image names, paths, configs, environment or raw errors.
if ! "${P[@]}" load --quiet --input "$archive" >"$lab/load.out" 2>"$lab/error.log"; then
  mark ROOTLESS_IMAGE_IMPORT FAIL
  exit 5
fi
mark ROOTLESS_IMAGE_IMPORT PASS
if ! "${P[@]}" images --all --no-trunc --format json >"$lab/images.json" 2>"$lab/error.log"; then
  mark ROOTLESS_IMAGES_ENUMERATION FAIL
  exit 5
fi
python3 - "$lab/images.json" <<'PY' || { mark IMPORTED_IMAGE_COUNT FAIL; exit 5; }
import json, pathlib, sys
entries=json.loads(pathlib.Path(sys.argv[1]).read_text())
if not isinstance(entries,list): raise SystemExit(1)
ids={e.get("Id") or e.get("ID") for e in entries if isinstance(e,dict)}
if None in ids or len(ids)!=3: raise SystemExit(1)
PY
mark IMPORTED_IMAGE_COUNT_3 PASS
mark ARCHIVED_IMAGES_RELOAD_IN_INDEPENDENT_STORE PASS
mark ARCHIVED_IMAGES_EXECUTED NO
mark O5_IMAGE_COMPATIBILITY_VERIFIED NO
mark EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED NO
mark OFF_HOST_COPY_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
