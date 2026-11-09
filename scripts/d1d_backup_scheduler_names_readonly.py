#!/usr/bin/env python3
"""D1-D: non-privileged, metadata-only backup scheduler discovery.

Only lists matching names of unit/timer/cron files and loaded systemd unit
names. Never reads unit contents, cron contents, env vars, secrets or backups.
Never invokes sudo, restic, rclone or modifies any service.
"""
from pathlib import Path
import os
import re
import subprocess
import sys

ROOTS = (
    Path("/etc/systemd/system"),
    Path("/lib/systemd/system"),
    Path("/usr/lib/systemd/system"),
    Path.home() / ".config/systemd/user",
    Path("/etc/cron.d"),
    Path("/etc/cron.daily"),
    Path("/etc/cron.hourly"),
    Path("/etc/cron.weekly"),
)
NEEDLE = re.compile(r"(o5|restic|rclone|vencira.*backup|backup.*vencira)", re.I)
SUFFIX = {".timer", ".service", ".path", ".socket", ".target"}
def mark(key, value):
    print("D1D_" + key + "=" + str(value), flush=True)
def safe(value):
    return re.sub(r"[^a-zA-Z0-9_.@-]", "_", value)[:100]
def discover_dir(root):
    if not root.is_dir():
        return 0
    matches = []
    # Top-level files only, plus one level of systemd *.wants symlinks.
    try:
        for p in root.iterdir():
            if NEEDLE.search(p.name) and (p.suffix in SUFFIX or "cron" in root.parts):
                matches.append(safe(p.name))
            elif p.is_dir() and p.name.endswith(".wants"):
                try:
                    matches.extend(safe(f"{p.name}/{x.name}") for x in p.iterdir()
                        if NEEDLE.search(x.name) and x.suffix in SUFFIX)
                except OSError:
                    pass
    except OSError:
        return 0
    for name in sorted(set(matches)):
        mark("MATCH", safe(root.name) + ":" + name)
    return len(set(matches))
def systemd(scope):
    cmd = ["systemctl"]
    if scope == "user":
        cmd.append("--user")
    cmd += ["list-unit-files", "--all", "--no-pager", "--no-legend",
            "--type=service", "--type=timer"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=12)
    except (OSError, subprocess.TimeoutExpired):
        return "UNAVAILABLE"
    if p.returncode:
        return "UNAVAILABLE"
    names = set()
    for line in p.stdout.splitlines():
        parts = line.split()
        if parts and NEEDLE.search(parts[0]) and parts[0].endswith(
                (".service", ".timer")):
            names.add(safe(parts[0]))
    for name in sorted(names):
        mark(scope.upper() + "_UNIT_NAME", name)
    return len(names)
def main():
    mark("READ_ONLY", "YES")
    mark("NO_SUDO", "YES")
    mark("NO_UNIT_CONTENT_READ", "YES")
    mark("NO_SECRET_OR_BACKUP_ACCESS", "YES")
    total = sum(discover_dir(root) for root in ROOTS)
    mark("UNIT_OR_CRON_NAMES_FOUND", total)
    mark("SYSTEM_UNIT_NAMES_FOUND", systemd("system"))
    mark("USER_UNIT_NAMES_FOUND", systemd("user"))
    mark("BACKUP_EXISTS", "NOT_VERIFIED")
    mark("BACKUP_RESTORE", "NOT_VERIFIED")
    mark("BACKUP_SCHEDULE_ACTIVE", "NOT_VERIFIED")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    mark("RESULT", 0)
if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        mark("ERROR_TYPE", type(exc).__name__)
        mark("RESULT", 1)
        sys.exit(1)
