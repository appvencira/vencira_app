#!/usr/bin/env bash
# D4-C: isolated rootless archived PostgreSQL 17 runtime smoke test.
# Synthetic data only. No host Docker socket, root, sudo, host mounts or O5 restore.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf "D4C_%s=%s\n" "$1" "$2"; }
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
for tool in git python3 sha256sum df mktemp podman openssl grep; do
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
# Keep runroot beneath the operator-owned XDG runtime filesystem rather
# than HOME; this is a targeted A/B response to the runtime-dir failure 125.
# Neither path is shared with host Docker or other Podman image stores.
if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -d "$XDG_RUNTIME_DIR" ||
      -L "$XDG_RUNTIME_DIR" ||
      "$(stat -c %u "$XDG_RUNTIME_DIR")" != "$(id -u)" ]]; then
  mark XDG_RUNTIME_DIRECTORY FAIL
  mark RESULT 4
  exit 4
fi
mark XDG_RUNTIME_DIRECTORY PASS
lab="$(mktemp -d "$workspace/d4c-rootless.XXXXXXXX")"
chmod 700 "$lab"
runtime_lab="$(mktemp -d "$XDG_RUNTIME_DIR/d4c-runroot.XXXXXXXX")"
chmod 700 "$runtime_lab"
cleanup(){
  rc=$?
  trap - EXIT
  case "$lab" in "$workspace"/d4c-rootless.*) ;; *) mark CLEANUP_PATH FAIL; exit 9;; esac
  case "$runtime_lab" in "$XDG_RUNTIME_DIR"/d4c-runroot.*) ;; *) mark CLEANUP_PATH FAIL; exit 9;; esac
  cleanup_ok=YES
  # Remove any left-behind containers only from this private Podman store.
  if [[ "${#container_names[@]}" -gt 0 ]]; then
    for cname in "${container_names[@]}"; do
      "${P[@]}" rm -f --ignore "$cname" >/dev/null 2>&1 || cleanup_ok=NO
    done
  fi
  if [[ -d "$lab" && ! -L "$lab" ]]; then
    # VFS layers may contain subordinate-UID ownership and read-only dirs.
    # Only operate on the fresh, validated D4-C private storage directory.
    if podman unshare sh -c '
      target="$1"
      test -d "$target" && test ! -L "$target" || exit 1
      find "$target" -type d -exec chmod u+rwx -- {} + || exit 1
      rm -rf -- "$target"
    ' sh "$lab"; then
      [[ ! -e "$lab" ]] || cleanup_ok=NO
    else
      cleanup_ok=NO
    fi
  else
    cleanup_ok=NO
  fi
  if [[ -d "$runtime_lab" && ! -L "$runtime_lab" ]]; then
    rm -rf -- "$runtime_lab" || cleanup_ok=NO
  else
    cleanup_ok=NO
  fi
  [[ "$cleanup_ok" == YES ]] || rc=9
  mark EPHEMERAL_STORAGE_REMOVED "$cleanup_ok"
  mark HOST_DOCKER_IMAGE_LOAD_EXECUTED NO
  mark CONTAINER_RUN_EXECUTED "$executed"
  mark OPERATIONAL_ROLLBACK_VERIFIED NO
  mark PUBLIC_RELEASE_AUTHORIZED NO
  mark RESULT "$rc"
  exit "$rc"
}
executed=NO
container_names=()
P=()
trap cleanup EXIT
mkdir -m 700 "$lab/graph" "$lab/tmp" "$runtime_lab/run"
# Keep the operator's real HOME, XDG_CONFIG_HOME, and XDG_RUNTIME_DIR:
# rootless Podman may resolve account/runtime state through these paths.
# The actual images and ephemeral run state remain explicitly scoped to the
# unique --root and --runroot below. Do not alter the host storage.conf.
export TMPDIR="$lab/tmp"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  [[ -d "$XDG_RUNTIME_DIR" && ! -L "$XDG_RUNTIME_DIR" &&
     "$(stat -c %u "$XDG_RUNTIME_DIR")" == "$(id -u)" ]] || {
    mark ROOTLESS_RUNTIME_ENV FAIL
    exit 4
  }
  mark ROOTLESS_RUNTIME_ENV PASS
else
  mark ROOTLESS_RUNTIME_ENV NOT_SET
fi
P=(podman --remote=false --root "$lab/graph" --runroot "$runtime_lab/run" --storage-driver vfs --events-backend=file)
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
print("D4C_PODMAN_INFO_ERROR_CATEGORY=" + category)
print("D4C_PODMAN_INFO_EXIT_CODE=" + sys.argv[2])
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
if ! "${P[@]}" load --quiet --input "$archive" >"$lab/load.out" 2>"$lab/error.log"; then
  mark ROOTLESS_IMAGE_IMPORT FAIL
  exit 5
fi
mark ROOTLESS_IMAGE_IMPORT PASS
if ! "${P[@]}" images --all --no-trunc --format json >"$lab/images.json" 2>"$lab/error.log"; then
  mark ROOTLESS_IMAGES_ENUMERATION FAIL
  exit 5
fi
if ! python3 - "$lab/images.json" "$lab/image_ids" <<'PY'
import json, pathlib, re, sys
items=json.loads(pathlib.Path(sys.argv[1]).read_text())
if not isinstance(items,list): raise SystemExit(1)
ids={str(x.get("Id") or x.get("ID") or "") for x in items if isinstance(x,dict)}
if len(ids)!=3 or any(not re.fullmatch(r"(?:sha256:)?[a-f0-9]{64}",i) for i in ids):
    raise SystemExit(1)
pathlib.Path(sys.argv[2]).write_text("\n".join(sorted(ids))+"\n")
PY
then
  mark IMPORTED_IMAGE_COUNT_3 FAIL
  exit 5
fi
mark IMPORTED_IMAGE_COUNT_3 PASS

# Identify the PostgreSQL image by the official image's POSTGRES_VERSION
# metadata; inspect output remains entirely private and is removed on exit.
postgres_id=""
postgres_count=0
i=0
while IFS= read -r image_id; do
  i=$((i+1))
  if ! "${P[@]}" image inspect "$image_id" >"$lab/inspect-$i.json" 2>"$lab/error.log"; then
    mark IMAGE_METADATA_READ FAIL
    exit 5
  fi
  if python3 - "$lab/inspect-$i.json" <<'PY'
import json, sys
items=json.load(open(sys.argv[1]))
if not isinstance(items,list) or len(items)!=1: raise SystemExit(2)
env=(items[0].get("Config") or {}).get("Env") or []
if not isinstance(env,list): raise SystemExit(2)
raise SystemExit(0 if any(isinstance(e,str) and e.startswith("PG_MAJOR=17") for e in env) else 1)
PY
  then
    postgres_id="$image_id"
    postgres_count=$((postgres_count+1))
  fi
done <"$lab/image_ids"
if [[ "$postgres_count" -ne 1 ]]; then
  mark ARCHIVED_PG17_ROLE_IDENTITY FAIL
  exit 6
fi
mark ARCHIVED_PG17_ROLE_IDENTITY PASS

# Rootless isolated PG17 smoke test: no ports, no network, no persistent mounts,
# no O5 data, random synthetic credentials, PostgreSQL data only in tmpfs.
password="$(openssl rand -hex 24)"
name="d4c-pg-$(basename "$lab" | tr -cd 'a-zA-Z0-9')"
container_names+=("$name")
if ! "${P[@]}" run -d --name "$name" --pull never \
    --network none --read-only --security-opt no-new-privileges \
    --pids-limit 128 --memory 1g \
    --tmpfs /var/lib/postgresql/data:rw,size=512m,mode=1777 \
    --tmpfs /var/run/postgresql:rw,size=64m,mode=1777 \
    --tmpfs /tmp:rw,size=64m,mode=1777 \
    -e POSTGRES_USER=d4c_synthetic -e POSTGRES_DB=d4c_synthetic \
    -e POSTGRES_PASSWORD="$password" \
    "$postgres_id" >"$lab/pg-container.id" 2>"$lab/error.log"; then
  mark PG17_START FAIL
  exit 6
fi
executed=YES
mark PG17_START PASS

ready=NO
for _ in $(seq 1 35); do
  if "${P[@]}" exec "$name" pg_isready -q -U d4c_synthetic -d d4c_synthetic >/dev/null 2>&1; then
    ready=YES
    break
  fi
  sleep 1
done
if [[ "$ready" != YES ]]; then
  mark PG17_READY FAIL
  exit 6
fi
mark PG17_READY PASS

# Check sample SQL only, without data or database dumps.
if "${P[@]}" exec "$name" psql -U d4c_synthetic -d d4c_synthetic -Atqc 'SELECT 1' 2>/dev/null | grep -qx 1; then
  mark PG17_SYNTHETIC_SQL PASS
else
  mark PG17_SYNTHETIC_SQL FAIL
  exit 6
fi
mark NO_EXTERNAL_NETWORK YES
mark NO_HOST_DOCKER_SOCKET YES
mark NO_PERSISTENT_PGDATA YES
mark IMAGE_API_WEB_STARTUP_VERIFIED NO
mark IMAGE_O5_COMPATIBILITY_VERIFIED NO
mark EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED NO
mark OFF_HOST_COPY_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
