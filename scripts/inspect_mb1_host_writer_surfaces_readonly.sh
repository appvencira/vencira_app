#!/usr/bin/env bash
# M1-03 host-only writer census, zero state changes and no secret output.
set -Eeuo pipefail
umask 077
if [ "${MB1_READONLY_HOST_CENSUS:-}" != YES ]; then
  echo "MB1_HOST_CENSUS_OPT_IN=REQUIRED"; exit 2
fi
command -v python3 >/dev/null
python3 - <<'PY'
import os, re, subprocess
from pathlib import Path

def run(*args):
    try:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                              text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None

# /proc/<pid>/comm reveals executable name, not command arguments,
# environment, working directories or credentials.
counts = {}
denied = 0
for item in Path('/proc').iterdir():
    if not item.name.isdigit():
        continue
    try:
        name = (item / 'comm').read_text().strip().lower()
    except (OSError, UnicodeError):
        denied += 1
        continue
    if name in {'postgres','python','python3','gunicorn','celery','cron','crond',
                'restic','rclone','pg_dump','pg_restore','docker','dockerd','containerd',
                'nginx','caddy'}:
        counts[name] = counts.get(name, 0) + 1
for name in sorted(counts):
    print(f"MB1_HOST_PROCESS_CLASS={name}:{counts[name]}")
print(f"MB1_HOST_PROC_UNREADABLE_COUNT={denied}")
# Names of active timers only. Never print command lines or unit details.
r=run('systemctl','list-timers','--all','--no-legend','--no-pager')
if r is None or r.returncode != 0:
    print("MB1_HOST_TIMERS=UNAVAILABLE")
else:
    names=set(re.findall(r'\b(?:vencira[-\w]*|[^\s]*backup[^\s]*|[^\s]*restic[^\s]*)\.timer\b',
                         r.stdout,re.I))
    for name in sorted(names):
        if re.fullmatch(r'[a-zA-Z0-9_.@-]+',name):
            print(f"MB1_HOST_TIMER_NAME={name}")
    print(f"MB1_HOST_MATCHING_TIMER_COUNT={len(names)}")
# Non-systemd user crontabs, external SQL clients and host mount writers cannot
# be proven absent with this census; fail closed.
print("MB1_HOST_USER_CRONTABS=NOT_VERIFIED")
print("MB1_HOST_EXTERNAL_SQL_WRITERS=NOT_VERIFIED")
print("MB1_HOST_SHARED_BIND_WRITERS=NOT_VERIFIED")
print("MB1_HOST_NONCOOPERATIVE_WRITERS=NOT_EXCLUDED")
print("MB1_HOST_CENSUS_RESULT=INVENTORY_ONLY")
print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
print("MB1_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
