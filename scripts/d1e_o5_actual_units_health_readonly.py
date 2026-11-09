#!/usr/bin/env python3
"""D1-E: systemd O5 service/timer health metadata, read-only.

The unit names are exact, confirmed by D1-D. No journal, unit contents,
EnvironmentFile, restic, database, credentials or backup payload are opened.
Service inactive is normal between timer runs; success requires corroboration.
"""
import subprocess
import sys

UNITS = (
    "vencira-o5-backup.timer",
    "vencira-o5-health.timer",
    "vencira-o5-backup.service",
    "vencira-o5-health.service",
)
FIELDS = (
    "LoadState", "ActiveState", "UnitFileState", "Result",
    "LastTriggerUSec", "NextElapseUSecRealtime",
    "ExecMainCode", "ExecMainStatus",
)

def marker(name, value):
    print("D1E_" + name + "=" + str(value), flush=True)

def properties(name):
    command = ["systemctl", "show", name, "--no-pager"]
    for key in FIELDS:
        command.append("--property=" + key)
    p = subprocess.run(command, capture_output=True, text=True,
                       timeout=12, check=False)
    if p.returncode:
        raise RuntimeError("systemctl show unavailable")
    parsed = {}
    for line in p.stdout.splitlines():
        key, sep, value = line.partition("=")
        if sep and key in FIELDS:
            parsed[key] = value
    return parsed

def safe_enum(value, allowed):
    return value if value in allowed else "UNKNOWN"

def main():
    marker("READ_ONLY", "YES")
    marker("REAL_UNIT_NAMES", "YES")
    timer_count = 0
    for unit in UNITS:
        p = properties(unit)
        label = unit.removeprefix("vencira-").replace("-", "_").replace(".", "_").upper()
        load = safe_enum(p.get("LoadState"), {
            "loaded", "not-found", "masked", "error", "bad-setting",
            "generated", "transient", "stub"})
        active = safe_enum(p.get("ActiveState"), {
            "active", "inactive", "failed", "activating", "deactivating"})
        enabled = safe_enum(p.get("UnitFileState"), {
            "enabled", "disabled", "static", "indirect", "masked",
            "generated", "transient", "linked", "linked-runtime"})
        marker(label + "_LOAD", load)
        marker(label + "_ACTIVE", active)
        marker(label + "_UNIT_FILE_STATE", enabled)
        if unit.endswith(".timer"):
            if load == "loaded" and active == "active":
                timer_count += 1
            # Only existence flags, not raw timestamps or unknown text.
            marker(label + "_LAST_TRIGGER_PRESENT",
                   "YES" if p.get("LastTriggerUSec", "") not in
                   ("", "n/a", "0", "Thu 1970-01-01 00:00:00 UTC") else "NO")
            marker(label + "_NEXT_ELAPSE_PRESENT",
                   "YES" if p.get("NextElapseUSecRealtime", "") not in
                   ("", "n/a", "0", "Thu 1970-01-01 00:00:00 UTC") else "NO")
        else:
            marker(label + "_RESULT", safe_enum(p.get("Result"), {
                "success", "exit-code", "signal", "core-dump", "timeout",
                "watchdog", "resources", "start-limit-hit", "protocol",
                "oom-kill", "exec-condition", "dependency"}))
            marker(label + "_EXEC_MAIN_STATUS",
                   p.get("ExecMainStatus") if p.get("ExecMainStatus", "").isdigit()
                   and len(p["ExecMainStatus"]) < 5 else "UNKNOWN")
    marker("ACTIVE_TIMERS", f"{timer_count}/2")
    marker("O5_BACKUP_SUCCESS", "NOT_VERIFIED")
    marker("O5_RESTIC_SNAPSHOT", "NOT_VERIFIED")
    marker("O5_RESTORE", "NOT_VERIFIED")
    marker("DEPLOY_EXECUTED", "NO")
    marker("LIVE_MIGRATIONS_EXECUTED", "NO")
    marker("MFA_RELEASE_AUTHORIZED", "NO")
    marker("NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    marker("RESULT", 0)

if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        marker("ERROR_TYPE", type(exc).__name__)
        marker("RESULT", 1)
        sys.exit(1)
