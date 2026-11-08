#!/usr/bin/env python3
"""D1-B read-only inventory of current DEV Compose and O5 backup units.

No config content, secrets, database access, restic snapshots or deploy.
Intentionally reports only unit health and Compose metadata file basenames.
"""
import os
import subprocess
import sys
from pathlib import PurePosixPath

SERVICE = "vencira_localcheck-api-1"
UNIT_NAMES = (
    "o5-backup.timer",
    "o5-health.timer",
    "o5-backup.service",
    "o5-health.service",
)


def command(args, timeout=12):
    return subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout, check=False)


def show(name, value):
    print(f"D1B_{name}={value}", flush=True)


def safe_filename_paths(value):
    if not value:
        return "NOT_SET"
    # Docker Compose normally stores comma-separated config_paths. Do
    # not expose host directories, home folders or contents.
    return ",".join(PurePosixPath(part.strip()).name for part in
                    value.split(",") if part.strip()) or "NOT_SET"


def main():
    show("READ_ONLY", "YES")
    show("RELEASE_AUTHORIZED", "NO")
    docker = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    inspect = command(docker + [
        "inspect", "--format",
        '{{index .Config.Labels "com.docker.compose.project"}}|'
        '{{index .Config.Labels "com.docker.compose.project.config_files"}}|'
        '{{index .Config.Labels "com.docker.compose.project.working_dir"}}',
        SERVICE,
    ])
    if inspect.returncode:
        raise RuntimeError("docker inspect failed")
    parts = inspect.stdout.strip().split("|")
    if len(parts) != 3 or parts[0] != "vencira_localcheck":
        raise RuntimeError("wrong Docker Compose project")
    show("COMPOSE_PROJECT", "vencira_localcheck")
    show("COMPOSE_FILENAMES", safe_filename_paths(parts[1]))
    show("COMPOSE_WORKDIR_BASENAME",
         PurePosixPath(parts[2]).name if parts[2] else "NOT_SET")

    # Systemctl's "is-enabled" and "is-active" query metadata only.
    # Do not inspect units' EnvironmentFiles or run restic / pg_dump.
    for unit in UNIT_NAMES:
        name = unit.upper().replace("-", "_").replace(".", "_")
        active = command(["systemctl", "is-active", unit])
        enabled = command(["systemctl", "is-enabled", unit])
        state = active.stdout.strip() or "UNKNOWN"
        mode = enabled.stdout.strip() or "UNKNOWN"
        show(name + "_ACTIVE", state)
        show(name + "_ENABLED", mode)
    show("BACKUP_RESTORE_VERIFIED", "NO")
    show("MIGRATION_COMPATIBILITY_VERIFIED", "NO")
    show("DEPLOY_EXECUTED", "NO")
    show("LIVE_MIGRATIONS_EXECUTED", "NO")
    show("RESULT", 0)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError,
            subprocess.TimeoutExpired) as error:
        show("ERROR_TYPE", type(error).__name__)
        show("RESULT", 1)
        sys.exit(1)
