#!/usr/bin/env bash
# M1-03: read-only inspection of actual scheduler definitions.
# No printing cron commands, arguments, env, paths, or credentials.
set -Eeuo pipefail
if [ "${MB1_EFFECTIVE_SCHEDULER_AUDIT:-}" != YES ]; then
  echo "MB1_SCHEDULER_AUDIT_OPT_IN=REQUIRED"; exit 2
fi
python3 - <<'PY'
import os, pathlib, re, subprocess
signals = {
    "VENCIRA": re.compile(r"vencira|manage\.py|renewal_attachments", re.I),
    "SQL": re.compile(r"psql|pg_dump|pg_restore|postgres|POSTGRES_", re.I),
    "OBJECT": re.compile(r"restic|rclone|attachment|/srv/storage", re.I),
    "EXEC": re.compile(r"docker\s+(?:exec|compose|run)|python(?:3)?\s+", re.I),
}
roots = [pathlib.Path("/etc/crontab"), pathlib.Path("/etc/cron.d")]
files=[]
for root in roots:
    try:
        if root.is_file(): files.append(root)
        elif root.is_dir(): files.extend(sorted(p for p in root.iterdir() if p.is_file() and not p.is_symlink()))
    except OSError:
        print("MB1_SCHEDULER_CRON_ENUMERATION=INCOMPLETE")
flagged=0; unreadable=0; total=0
for p in files:
    total+=1
    try: content=p.read_text(errors="replace")
    except OSError:
        unreadable+=1
        continue
    # Do not output filename or content; names may reveal private details.
    body="\n".join(x for x in content.splitlines() if x.strip() and not x.lstrip().startswith("#"))
    labels=[name for name,rx in signals.items() if rx.search(body)]
    if labels:
        flagged+=1
        print("MB1_SCHEDULER_CRON_MATCH=" + ",".join(labels))
print(f"MB1_SCHEDULER_CRON_FILES={total}")
print(f"MB1_SCHEDULER_CRON_UNREADABLE={unreadable}")
print(f"MB1_SCHEDULER_CRON_FLAGGED={flagged}")
# Unit files can contain environment secrets, so classify privately, output only flags.
for unit in ("vencira-o5-backup.service","vencira-o5-health.service"):
    try:
        r=subprocess.run(["systemctl","cat",unit],capture_output=True,text=True,timeout=8)
        if r.returncode!=0:
            print("MB1_SCHEDULER_O5_UNIT=UNAVAILABLE")
            continue
        labels=[name for name,rx in signals.items() if rx.search(r.stdout)]
        print("MB1_SCHEDULER_O5_UNIT_CLASS=" + (",".join(labels) if labels else "OTHER"))
    except (OSError,subprocess.TimeoutExpired):
        print("MB1_SCHEDULER_O5_UNIT=UNAVAILABLE")
print("MB1_SCHEDULER_CRON_ENTRIES=CLASSIFIED_NOT_DISCLOSED")
print("MB1_SCHEDULER_SQL_PERMISSIONS=NOT_VERIFIED")
print("MB1_SCHEDULER_WRITER_EXCLUSION=NOT_VERIFIED")
print("MB1_SCHEDULER_AUDIT_RESULT=INVENTORY_ONLY")
print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
print("MB1_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
