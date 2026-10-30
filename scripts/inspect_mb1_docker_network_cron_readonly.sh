#!/usr/bin/env bash
# Read-only M1-03 census: Docker network membership and cron metadata.
set -Eeuo pipefail
if [ "${MB1_READONLY_NETWORK_CRON:-}" != YES ]; then
  echo "MB1_NETWORK_CRON_OPT_IN=REQUIRED"; exit 2
fi
python3 - <<'PY'
import json, os, pathlib, subprocess
def cmd(*args):
    try:
        return subprocess.run(args,capture_output=True,text=True,timeout=12,check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None

# Docker inspect prints neither credentials, IPs nor raw network topology;
# emit only project/service and internal-network membership counts.
ids=cmd("docker","ps","-q")
if ids is None or ids.returncode:
    print("MB1_DOCKER_ACCESS=UNAVAILABLE")
else:
    names=ids.stdout.split()
    if names:
        r=cmd("docker","inspect",*names)
        if r and r.returncode==0:
            data=json.loads(r.stdout)
            for item in data:
                lab=(item.get("Config",{}).get("Labels") or {})
                project=lab.get("com.docker.compose.project","")
                if not project.startswith("vencira"): continue
                service=lab.get("com.docker.compose.service","unknown")
                net=item.get("NetworkSettings",{}).get("Networks") or {}
                ports=item.get("NetworkSettings",{}).get("Ports") or {}
                exposed=sum(len(v or []) for v in ports.values())
                print(f"MB1_DOCKER_SERVICE_NETWORK={project}/{service}:NETWORKS={len(net)}:PUBLISHED_BINDINGS={exposed}")
            print("MB1_DOCKER_NETWORK_CENSUS=OK")
        else: print("MB1_DOCKER_NETWORK_CENSUS=UNAVAILABLE")
    else: print("MB1_DOCKER_NETWORK_CENSUS=NO_RUNNING_CONTAINERS")

# Metadata only: names / counts of cron configuration files, not contents.
for label,path in (("ETC_CRON_D","/etc/cron.d"),("SPOOL_CRONTABS","/var/spool/cron/crontabs")):
    try:
        with os.scandir(path) as entries:
            n=sum(1 for x in entries if x.is_file(follow_symlinks=False))
        print(f"MB1_{label}_FILE_COUNT={n}")
    except PermissionError:
        print(f"MB1_{label}_FILE_COUNT=ACCESS_DENIED")
    except OSError:
        print(f"MB1_{label}_FILE_COUNT=UNKNOWN")
print("MB1_CRON_COMMANDS=NOT_INSPECTED")
print("MB1_EXTERNAL_SQL_CLIENTS=NOT_EXCLUDED")
print("MB1_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED")
print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
print("MB1_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
