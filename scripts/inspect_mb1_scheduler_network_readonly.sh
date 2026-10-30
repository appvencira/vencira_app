#!/usr/bin/env bash
# M1-03 readonly scheduler/network census. No secrets, no cron content, no SQL.
set -Eeuo pipefail
if [ "${MB1_READONLY_SCHEDULER_CENSUS:-}" != YES ]; then
  echo "MB1_SCHEDULER_CENSUS_OPT_IN=REQUIRED"
  exit 2
fi
python3 - <<'PY'
import os, pathlib, re, subprocess
def command(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=8, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None

# Check presence only. Never print cron expressions or commands.
for label, path in (
    ("SYSTEM_CRONTAB", "/etc/crontab"),
    ("SYSTEM_CRON_D", "/etc/cron.d"),
    ("ROOT_CRON_SPOOL", "/var/spool/cron/crontabs/root"),
    ("USER_CRON_SPOOL_DIR", "/var/spool/cron/crontabs"),
):
    p=pathlib.Path(path)
    try:
        present=p.exists()
        readable=os.access(path, os.R_OK)
        print(f"MB1_{label}=" + ("PRESENT" if present else "NOT_PRESENT") +
              (":READABLE" if readable else ":NOT_READABLE"))
    except OSError:
        print(f"MB1_{label}=UNKNOWN")

r=command("ss","-ltnH")
if r is None or r.returncode != 0:
    print("MB1_POSTGRES_TCP_LISTEN=UNVERIFIED")
else:
    # Endpoint addresses are intentionally not emitted.
    lines=[line.split() for line in r.stdout.splitlines()]
    port5432=sum(1 for f in lines if len(f)>3 and
                 re.search(r"(?:^|:|\])5432$",f[3]))
    print(f"MB1_HOST_TCP_5432_LISTENER_COUNT={port5432}")
    print("MB1_EXTERNAL_SQL_AUTHORIZATION=NOT_VERIFIED")
print("MB1_CONTAINER_NETWORK_EXPOSURE=NOT_VERIFIED")
print("MB1_CRON_CONTENT_AND_OTHER_USERS=NOT_VERIFIED")
print("MB1_SHARED_BIND_WRITERS=NOT_VERIFIED")
print("MB1_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED")
print("MB1_SCHEDULER_NETWORK_RESULT=INVENTORY_ONLY")
print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
print("MB1_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
