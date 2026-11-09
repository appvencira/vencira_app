#!/usr/bin/env python3
"""D1-J: privileged, READ-ONLY O5 wrapper contract classification.

This tool intentionally DOES NOT execute any wrapper, Restic, Rclone,
PostgreSQL, or Docker command. It reads exactly two systemd unit fragments
and their direct ExecStart wrapper texts, and prints fixed vocabulary only.
The operator should inspect this script from trusted main before sudo.
No secrets, paths, commands, arguments, file bodies or variable values
are printed. A successful scan is NOT snapshot or restore verification.
"""
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

UNITS = {"BACKUP": "vencira-o5-backup.service",
         "HEALTH": "vencira-o5-health.service"}
MAX_SOURCE_BYTES = 256 * 1024
PROBES = {
    "RESTIC": r"\brestic\b",
    "RCLONE": r"\brclone\b",
    "PG_DUMP": r"\bpg_dump(?:all)?\b",
    "PG_RESTORE": r"\bpg_restore\b|\bpsql\b",
    "DOCKER": r"\bdocker\b",
    "S3_BACKEND": r"\bs3:",
    "RESTIC_SNAPSHOTS": r"\brestic\s+(?:[\w-]+\s+)*snapshots\b",
    "RESTIC_CHECK": r"\brestic\s+(?:[\w-]+\s+)*check\b",
    "RESTIC_RESTORE": r"\brestic\s+(?:[\w-]+\s+)*restore\b",
    "RESTIC_BACKUP": r"\brestic\s+(?:[\w-]+\s+)*backup\b",
    "RESTIC_FORGET_PRUNE": r"\brestic\s+(?:[\w-]+\s+)*(?:forget|prune)\b",
    "ENVFILE_SOURCE": r"(^|\n)\s*(?:source|\.)\s+[^\n]+|\bEnvironmentFile\b",
}
def mark(k, value):
    print("D1J_" + k + "=" + str(value), flush=True)

def path_from_systemd(unit):
    result = subprocess.run(
        ["systemctl", "show", unit, "--property=FragmentPath", "--value"],
        capture_output=True, text=True, timeout=12, check=False)
    if result.returncode:
        raise RuntimeError("unable to read unit metadata")
    fragment = result.stdout.strip()
    if not fragment.startswith("/"):
        raise RuntimeError("unit fragment is not absolute")
    file = Path(fragment)
    if not file.is_file():
        raise RuntimeError("unit fragment unavailable")
    return file

def bounded_read(file):
    if file.is_symlink():
        raise RuntimeError("symlink target requires manual review")
    if file.stat().st_size > MAX_SOURCE_BYTES:
        raise RuntimeError("oversized source requires manual review")
    return file.read_text(encoding="utf-8", errors="replace")

def extract_target(unit):
    source = bounded_read(path_from_systemd(unit))
    section = ""
    entries = []
    for line in source.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line.lower()
        if section == "[service]" and line.startswith("ExecStart="):
            entries.append(line.split("=", 1)[1].strip())
    if len(entries) != 1:
        raise RuntimeError("expected one ExecStart")
    argv = shlex.split(entries[0])
    if not argv:
        raise RuntimeError("empty ExecStart")
    name = argv[0].lstrip("-+!:@")
    if not name.startswith("/") or len(argv) != 1:
        raise RuntimeError("ExecStart contract changed; review manually")
    target = Path(name)
    if target.suffix not in (".sh", ""):
        raise RuntimeError("non-shell wrapper requires manual review")
    if not target.is_file():
        raise RuntimeError("wrapper not readable")
    return target

def main():
    mark("READ_ONLY", "YES")
    mark("PRIVILEGED_SOURCE_CLASSIFICATION", "YES" if os.geteuid() == 0 else "NO")
    mark("EXECUTION_OF_WRAPPERS", "NO")
    mark("RESTIC_EXECUTED", "NO")
    mark("SECRET_OUTPUT", "NO")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    mark("MFA_RELEASE_AUTHORIZED", "NO")
    mark("NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    if os.geteuid() != 0:
        raise RuntimeError("privileged read-only review requires root")
    for label, unit in UNITS.items():
        wrapper = extract_target(unit)
        source = bounded_read(wrapper)
        mark(label + "_WRAPPER_READABLE", "YES")
        mark(label + "_WRAPPER_NONEMPTY", "YES" if source.strip() else "NO")
        for name, pattern in PROBES.items():
            mark(label + "_" + name + "_MENTION",
                 "YES" if re.search(pattern, source, re.I | re.M) else "NO")
        # Merely inventory: do NOT infer executable commands from regex matches.
        mark(label + "_SCRIPT_CONTRACT", "STATIC_KEYWORD_INVENTORY_ONLY")
    mark("SNAPSHOT_EXISTS", "NOT_VERIFIED")
    mark("SNAPSHOT_FRESHNESS", "NOT_VERIFIED")
    mark("SNAPSHOT_RESTORE", "NOT_VERIFIED")
    mark("RESULT", 0)
if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        mark("ERROR_TYPE", type(exc).__name__)
        mark("RESULT", 1)
        sys.exit(1)
