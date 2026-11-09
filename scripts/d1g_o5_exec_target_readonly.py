#!/usr/bin/env python3
"""D1-G: classify installed O5 ExecStart targets, no execution or disclosure.

Read only service unit fragments. No logs, env files, helper contents, restic,
rclone, backups or database. Never output paths, raw commands or arguments.
"""
from pathlib import Path
import os
import re
import shlex
import subprocess
import sys

UNITS = ("vencira-o5-backup.service", "vencira-o5-health.service")
INTERPRETERS = {"bash", "sh", "dash", "python", "python3", "env"}
DIRECT_TOOLS = {"restic", "rclone", "docker", "podman"}
VALID_NAME = re.compile(r"^[A-Za-z0-9_.-]+$")

def mark(k, v):
    print("D1G_" + k + "=" + str(v), flush=True)

def fragment_of(unit):
    p = subprocess.run(
        ["systemctl", "show", unit, "--property=FragmentPath", "--value"],
        capture_output=True, text=True, timeout=12, check=False)
    if p.returncode:
        raise RuntimeError("unit fragment lookup failed")
    path = p.stdout.strip()
    if not path.startswith("/") or not Path(path).is_file():
        raise RuntimeError("unit fragment not accessible")
    return Path(path)

def classify(unit):
    prefix = "BACKUP" if "-backup." in unit else "HEALTH"
    text = fragment_of(unit).read_text(encoding="utf-8", errors="replace")
    section = None
    starts = []
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line.lower()
            continue
        if section == "[service]" and line.startswith("ExecStart="):
            starts.append(line.partition("=")[2].strip())
    if len(starts) != 1:
        mark(prefix + "_EXECSTART_COUNT", len(starts))
        raise RuntimeError("expected one explicit ExecStart")
    mark(prefix + "_EXECSTART_COUNT", 1)
    try:
        argv = shlex.split(starts[0], posix=True)
    except ValueError:
        mark(prefix + "_COMMAND_PARSE", "UNAVAILABLE")
        raise RuntimeError("cannot parse ExecStart")
    if not argv:
        raise RuntimeError("empty ExecStart")
    # systemd supports special prefixes; strip only to classify executable.
    program = argv[0].lstrip("-+!:@")
    program_name = Path(program).name
    if not VALID_NAME.fullmatch(program_name):
        mark(prefix + "_EXEC_CLASS", "UNKNOWN")
        return
    if program_name in INTERPRETERS:
        category = "INTERPRETER"
    elif program_name in DIRECT_TOOLS:
        category = "DIRECT_TOOL"
    elif any(x in program_name.lower() for x in ("o5", "vencira", "backup", "health")):
        category = "PROJECT_WRAPPER"
    else:
        category = "OTHER_EXECUTABLE"
    mark(prefix + "_EXEC_CLASS", category)
    mark(prefix + "_ARGS_PRESENT", "YES" if len(argv) > 1 else "NO")
    mark(prefix + "_EXEC_PATH_ABSOLUTE", "YES" if program.startswith("/") else "NO")
    # Only inspect a single direct argument when it looks like a script path.
    # Never print the path or basename: even filenames may be sensitive.
    script = None
    if category == "PROJECT_WRAPPER" and program.startswith("/"):
        script = Path(program)
    elif category == "INTERPRETER":
        for arg in argv[1:]:
            if arg.startswith("-"):
                continue
            if arg.startswith("/") and Path(arg).suffix in (".sh", ".py"):
                script = Path(arg)
            break
    if script is None:
        mark(prefix + "_HELPER_TARGET", "NOT_DETERMINED")
        return
    mark(prefix + "_HELPER_TARGET", "DETECTED")
    # Protected parent directories can raise PermissionError during stat().
    # This is an operator visibility limit, NOT evidence the backup failed.
    # Do not escalate privileges or turn inaccessible into missing.
    try:
        exists = script.is_file()
    except PermissionError:
        mark(prefix + "_HELPER_EXISTS", "PERMISSION_DENIED")
    else:
        mark(prefix + "_HELPER_EXISTS", "YES" if exists else "NO")
    # No file content, no access to target directory listings.
    mark(prefix + "_HELPER_EXTENSION",
         "SHELL" if script.suffix == ".sh" else
         "PYTHON" if script.suffix == ".py" else "OTHER")

def main():
    mark("READ_ONLY", "YES")
    mark("NO_SECRET_OR_HELPER_CONTENT_READ", "YES")
    mark("NO_BACKUP_OR_RESTORE", "YES")
    mark("NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    for unit in UNITS:
        classify(unit)
    mark("SNAPSHOT_VERIFIED", "NO")
    mark("RESTORE_VERIFIED", "NO")
    mark("RESULT", 0)

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        mark("ERROR_TYPE", type(error).__name__)
        mark("RESULT", 1)
        sys.exit(1)
