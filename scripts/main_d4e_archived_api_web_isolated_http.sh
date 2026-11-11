#!/usr/bin/env bash
# D4-E: isolated API+Web runtime test from archived images, with synthetic environment.
# No host Docker socket, sudo, network access, host mounts, live O5 or user data.
set -Eeuo pipefail
set +x
umask 077
mark(){ printf "D4E_%s=%s\n" "$1" "$2"; }
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
lab="$(mktemp -d "$workspace/d4e-rootless.XXXXXXXX")"
chmod 700 "$lab"
runtime_lab="$(mktemp -d "$XDG_RUNTIME_DIR/d4e-runroot.XXXXXXXX")"
chmod 700 "$runtime_lab"
cleanup(){
  rc=$?
  trap - EXIT
  case "$lab" in "$workspace"/d4e-rootless.*) ;; *) mark CLEANUP_PATH FAIL; exit 9;; esac
  case "$runtime_lab" in "$XDG_RUNTIME_DIR"/d4e-runroot.*) ;; *) mark CLEANUP_PATH FAIL; exit 9;; esac
  cleanup_ok=YES
  # Remove any left-behind containers only from this private Podman store.
  if [[ "${#container_names[@]}" -gt 0 ]]; then
    for cname in "${container_names[@]}"; do
      "${P[@]}" rm -f --ignore "$cname" >/dev/null 2>&1 || cleanup_ok=NO
    done
  fi
  if [[ -d "$lab" && ! -L "$lab" ]]; then
    # VFS layers may contain subordinate-UID ownership and read-only dirs.
    # Only operate on the fresh, validated D4-E private storage directory.
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
print("D4E_PODMAN_INFO_ERROR_CATEGORY=" + category)
print("D4E_PODMAN_INFO_EXIT_CODE=" + sys.argv[2])
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

# Classify API and WEB only by their archived startup contracts. No tags,
# image IDs, metadata values, environmental secrets or logs are printed.
api_id=""
web_id=""
api_count=0
web_count=0
i=0
while IFS= read -r image_id; do
  i=$((i+1))
  if ! "${P[@]}" image inspect "$image_id" >"$lab/inspect-$i.json" 2>"$lab/error.log"; then
    mark IMAGE_METADATA_READ FAIL
    exit 5
  fi
  role="$(python3 - "$lab/inspect-$i.json" <<'PY'
import json, sys
items=json.load(open(sys.argv[1]))
if not isinstance(items,list) or len(items)!=1: raise SystemExit(2)
cfg=items[0].get("Config") or {}
cmd=cfg.get("Cmd") or []
entry=cfg.get("Entrypoint") or []
env=cfg.get("Env") or []
if not all(isinstance(x,str) for x in cmd+entry+env): raise SystemExit(2)
if any("gunicorn" in x for x in cmd) and any(x.startswith("PYTHONDONTWRITEBYTECODE=") for x in env):
    print("API")
elif any("nginx" in x for x in cmd+entry):
    print("WEB")
else:
    print("OTHER")
PY
)" || { mark IMAGE_ROLE_CLASSIFICATION FAIL; exit 6; }
  case "$role" in
    API) api_id="$image_id"; api_count=$((api_count+1));;
    WEB) web_id="$image_id"; web_count=$((web_count+1));;
  esac
done <"$lab/image_ids"
if [[ "$api_count" -ne 1 || "$web_count" -ne 1 || "$api_id" == "$web_id" ]]; then
  mark UNIQUE_API_WEB_ROLES FAIL
  exit 6
fi
mark UNIQUE_API_WEB_ROLES PASS

# API service runs in a network-less namespace with a synthetically generated
# SECRET_KEY. SQLite remains inaccessible because the root FS is readonly;
# /api/health/ never queries a database. This gate is not a DB integration test.
secret="$(openssl rand -hex 32)"
api_name="d4e-api-$(basename "$lab" | tr -cd 'a-zA-Z0-9')"
container_names+=("$api_name")
if ! "${P[@]}" run -d --name "$api_name" --pull never \
    --network none --read-only --security-opt no-new-privileges \
    --pids-limit 96 --memory 512m \
    --tmpfs /tmp:rw,size=64m,mode=1777 \
    -e VENCIRA_ENV=test -e DJANGO_DEBUG=0 \
    -e DJANGO_SECRET_KEY="$secret" \
    -e DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost \
    -e VENCIRA_DB_ENGINE=sqlite -e VENCIRA_MFA_ENROLLMENT_ENABLED=0 \
    "$api_id" >"$lab/api.id" 2>"$lab/error.log"; then
  mark API_START FAIL
  exit 6
fi
executed=YES
mark API_START PASS

# Use Python inside the archived API image to query its own local HTTP port.
# No host port mappings or shared networks.
api_ok=NO
for _ in $(seq 1 30); do
  if "${P[@]}" exec "$api_name" python -c '
import json,urllib.request
with urllib.request.urlopen("http://127.0.0.1:8000/api/health/",timeout=2) as r:
    assert r.status==200 and json.load(r).get("status")=="ok"
' >/dev/null 2>&1; then
    api_ok=YES; break
  fi
  sleep 1
done
if [[ "$api_ok" != YES ]]; then mark API_HEALTH_HTTP FAIL; exit 6; fi
mark API_HEALTH_HTTP PASS

# The archived web image starts with its actual ENTRYPOINT and CMD.
web_name="d4e-web-$(basename "$lab" | tr -cd 'a-zA-Z0-9')"
container_names+=("$web_name")
if ! "${P[@]}" run -d --name "$web_name" --pull never \
    --network none --read-only --security-opt no-new-privileges \
    --pids-limit 96 --memory 256m \
    --tmpfs /tmp:rw,size=64m,mode=1777 \
    --tmpfs /var/cache/nginx:rw,size=64m,mode=1777 \
    --tmpfs /var/run:rw,size=16m,mode=1777 \
    "$web_id" >"$lab/web.id" 2>"$lab/error.log"; then
  mark WEB_START FAIL
  exit 7
fi
mark WEB_START PASS

# Use the web image's own HTTP client, if available, without host networking.
# wget availability and the server's default internal port are part of this
# deliberately strict smoke gate; failure is diagnostic, not image corruption.
web_ok=NO
for _ in $(seq 1 25); do
  if "${P[@]}" exec "$web_name" sh -c 'wget -q -O /dev/null http://127.0.0.1:80/' >/dev/null 2>&1; then
    web_ok=YES; break
  fi
  sleep 1
done
if [[ "$web_ok" != YES ]]; then
  # Diagnostic only. Distinguish application/port/runtime failures from a
  # missing wget utility; never print response bodies or container logs.
  state="$("${P[@]}" inspect --format '{{.State.Running}}' "$web_name" 2>/dev/null || true)"
  mark WEB_CONTAINER_STILL_RUNNING "$([[ "$state" == true ]] && echo YES || echo NO)"
  if [[ "$state" == true ]]; then
    if "${P[@]}" exec "$web_name" sh -c 'command -v wget >/dev/null 2>&1'; then
      mark WEB_WGET_AVAILABLE YES
    else
      mark WEB_WGET_AVAILABLE NO
    fi
    if "${P[@]}" exec "$web_name" nginx -t >"$lab/nginx-test.out" 2>"$lab/nginx-test.err"; then
      mark WEB_NGINX_CONFIG_TEST PASS
    else
      mark WEB_NGINX_CONFIG_TEST FAIL
    fi
    # /proc/net/tcp contains only sockets here; test 80/8080 by port
    # without printing addresses, process details or config.
    if "${P[@]}" exec "$web_name" sh -c 'grep -Eq ":[0]*0050[[:space:]].*[[:space:]]0A[[:space:]]" /proc/net/tcp'; then
      mark WEB_TCP80_LISTEN YES
    else
      mark WEB_TCP80_LISTEN NOT_VERIFIED
    fi
    if "${P[@]}" exec "$web_name" sh -c 'grep -Eq ":[0]*1F90[[:space:]].*[[:space:]]0A[[:space:]]" /proc/net/tcp'; then
      mark WEB_TCP8080_LISTEN YES
    else
      mark WEB_TCP8080_LISTEN NOT_VERIFIED
    fi
    # Probe only status metadata; output stays private inside ephemeral lab.
    if "${P[@]}" exec "$web_name" sh -c 'command -v wget >/dev/null && wget -S -O /dev/null -T 2 http://127.0.0.1:80/' >"$lab/web-probe.out" 2>"$lab/web-probe.err"; then
      mark WEB_HTTP80_WGET_EXIT SUCCESS
    else
      mark WEB_HTTP80_WGET_EXIT FAILURE
    fi
    python3 - "$lab/web-probe.err" <<'PY'
import pathlib, re, sys
data=pathlib.Path(sys.argv[1]).read_text(errors="replace")
codes=re.findall(r"HTTP/1(?:\\.[01])?\\s+([1-5][0-9][0-9])", data)
print("D4E_WEB_HTTP80_RESPONSE_CODE=" + (codes[-1] if codes else "NOT_OBSERVED"))
PY
  fi
  mark WEB_HTTP_LOCAL FAIL
  exit 7
fi
mark WEB_HTTP_LOCAL PASS
mark NO_EXTERNAL_NETWORK YES
mark NO_HOST_DOCKER_SOCKET YES
mark API_WEB_ISOLATED_RUNTIME PASS
mark DATABASE_INTEGRATION_VERIFIED NO
mark REAL_O5_COMPATIBILITY_VERIFIED NO
mark EXACT_ORIGINAL_DOCKER_IMAGE_ID_VERIFIED NO
mark OFF_HOST_COPY_VERIFIED NO
mark OPERATIONAL_ROLLBACK_VERIFIED NO
