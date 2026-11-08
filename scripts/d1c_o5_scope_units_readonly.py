#!/usr/bin/env python3
"""D1-C: read-only discovery of O5 backup systemd unit scope.

Never opens unit environment files, backups, credentials or restic repositories.
Reports whether a unit is loadable in system/user manager, plus effective state.
User manager queries are best-effort because Termius sessions may lack DBUS.
"""
import os
import shutil
import subprocess
import sys

UNITS = (
    "o5-backup.timer",
    "o5-health.timer",
    "o5-backup.service",
    "o5-health.service",
)
SCOPES = ("system", "user")

def mark(label, value):
    print(f"D1C_{label}={value}", flush=True)

def query(scope, unit, property_name):
    args = ["systemctl"]
    if scope == "user":
        args.append("--user")
    args.extend(["show", "--property=" + property_name,
                 "--value", "--", unit])
    try:
        p = subprocess.run(args, capture_output=True, text=True,
                           timeout=8, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return "UNAVAILABLE"
    if p.returncode != 0:
        return "UNAVAILABLE"
    result = p.stdout.strip()
    # Explicitly constrain the status output: never leak unit env content.
    if property_name == "LoadState":
        return result if result in {
            "loaded", "not-found", "masked", "error", "bad-setting",
            "stub", "merged", "transient", "generated"
        } else "UNKNOWN"
    if property_name == "ActiveState":
        return result if result in {
            "active", "inactive", "failed", "activating", "deactivating",
            "reloading", "maintenance", "refreshing"
        } else "UNKNOWN"
    return "UNKNOWN"

def main():
    mark("READ_ONLY", "YES")
    mark("RELEASE_AUTHORIZED", "NO")
    mark("NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    if shutil.which("systemctl") is None:
        raise RuntimeError("systemctl missing")
    system_loaded = 0
    user_loaded = 0
    for scope in SCOPES:
        for unit in UNITS:
            name = unit.replace("-", "_").replace(".", "_").upper()
            load = query(scope, unit, "LoadState")
            active = query(scope, unit, "ActiveState")
            mark(f"{scope.upper()}_{name}_LOAD", load)
            mark(f"{scope.upper()}_{name}_ACTIVE", active)
            if load == "loaded":
                if scope == "user":
                    user_loaded += 1
                else:
                    system_loaded += 1
    mark("SYSTEM_UNITS_LOADED", system_loaded)
    mark("USER_UNITS_LOADED", user_loaded)
    if user_loaded == 0 and system_loaded == 0:
        mark("O5_UNIT_REGISTRATION", "NOT_VERIFIED")
    elif user_loaded == len(UNITS) or system_loaded == len(UNITS):
        mark("O5_UNIT_REGISTRATION", "FOUND_NOT_BACKUP_VERIFIED")
    else:
        mark("O5_UNIT_REGISTRATION", "PARTIAL_REVIEW_REQUIRED")
    mark("O5_SNAPSHOT_VALID", "NOT_VERIFIED")
    mark("O5_RESTORE_VALID", "NOT_VERIFIED")
    mark("O5_BACKUP_SCHEDULE_HEALTH", "NOT_VERIFIED")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    mark("RESULT", 0)

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as exc:
        mark("ERROR_TYPE", type(exc).__name__)
        mark("RESULT", 1)
        sys.exit(1)
