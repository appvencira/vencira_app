#!/usr/bin/env bash
# Read-only inventory of real Docker writer surfaces for MB1 consistency planning.
# No docker stop, exec, SQL, migrations, mount changes, secrets, or freeze.
set -Eeuo pipefail
umask 077
if [ "${MB1_READONLY_WRITER_CENSUS:-}" != "YES" ]; then
  echo "MB1_WRITER_CENSUS_EXPLICIT_OPT_IN=REQUIRED"; exit 2
fi
command -v docker >/dev/null
command -v python3 >/dev/null
docker info >/dev/null 2>&1
# Only examine locally running VENCIRA containers; no effects on their state.
python3 - <<'PY'
import json, subprocess, sys
def docker(*args):
    return subprocess.check_output(["docker", *args], text=True, stderr=subprocess.DEVNULL)
try:
    ids = docker("ps", "-q").splitlines()
    data = json.loads(docker("inspect", *ids)) if ids else []
except (subprocess.CalledProcessError, json.JSONDecodeError):
    print("MB1_WRITER_CENSUS_INSPECT=FAILED")
    sys.exit(1)
selected = []
for x in data:
    labels = x.get("Config", {}).get("Labels") or {}
    project = labels.get("com.docker.compose.project", "")
    if project.startswith(("vencira",)) or x.get("Name", "").lstrip("/").startswith("vencira"):
        selected.append(x)
if not selected:
    print("MB1_WRITER_CENSUS_NO_VENCIRA_CONTAINERS=1")
    print("MB1_WRITER_CENSUS_RESULT=BLOCKED")
    sys.exit(2)
print("MB1_WRITER_CENSUS_RUNNING_VENCIRA=" + str(len(selected)))
# Labels and container names only; no env vars, mounts on host, passwords or IPs.
rw = []
for x in selected:
    labels = x.get("Config", {}).get("Labels") or {}
    project = labels.get("com.docker.compose.project", "unlabelled")
    service = labels.get("com.docker.compose.service", "unlabelled")
    name = x.get("Name", "").lstrip("/")
    print(f"MB1_WRITER_SERVICE={project}/{service}/{name}")
    state = x.get("State") or {}
    print("MB1_WRITER_SERVICE_RUNNING=" + ("YES" if state.get("Running") else "NO"))
    if x.get("HostConfig", {}).get("Privileged"):
        print("MB1_WRITER_PRIVILEGED_CONTAINER=YES")
    mounts = x.get("Mounts") or []
    for m in mounts:
        mode = "RW" if m.get("RW") else "RO"
        kind = m.get("Type", "unknown")
        target = m.get("Destination", "")
        print(f"MB1_WRITER_MOUNT={service}:{kind}:{mode}:{target}")
        if m.get("RW"):
            rw.append((service, kind, target))
print("MB1_WRITER_RW_MOUNT_COUNT=" + str(len(rw)))
print("MB1_WRITER_FILE_LOCK_COOPERATIVE=UNVERIFIED")
print("MB1_WRITER_ENTRYPOINT_COVERAGE=UNVERIFIED")
print("MB1_WRITER_NONDOCKER_PROCESSES=NOT_INVENTORIED")
print("MB1_WRITER_CENSUS_RESULT=INVENTORY_ONLY")
print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
print("MB1_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
