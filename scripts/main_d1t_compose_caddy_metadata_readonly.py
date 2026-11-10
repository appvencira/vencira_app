#!/usr/bin/env python3
"""D1-T: safely classify the live Compose manifest location and Caddy unit.

No raw config, environment values, secrets or paths are emitted. Never runs
compose config/up/down, systemctl start/reload, database operations or curl.
"""
import os
from pathlib import Path
import subprocess
import sys


def mark(name, value):
    print(f"D1T_{name}={value}", flush=True)


def run(args, timeout=15):
    try:
        cp = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RuntimeError("metadata command unavailable") from exc
    if cp.returncode:
        raise RuntimeError("metadata command unsuccessful")
    return cp.stdout.strip()


def secure_regular(path, *, max_size=2_000_000):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError("unexpected manifest file type")
    stat = path.stat()
    if stat.st_size > max_size or stat.st_size == 0:
        raise RuntimeError("unexpected manifest size")
    return path


def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    mark("READ_ONLY", "YES")
    mark("RELEASE_AUTHORIZED", "NO")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    docker = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    fmt = (
        '{{index .Config.Labels "com.docker.compose.project"}}|'
        '{{index .Config.Labels "com.docker.compose.project.working_dir"}}|'
        '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
    )
    raw = run(docker + [
        "inspect", "-f", fmt, "vencira_localcheck-api-1",
    ])
    parts = raw.split("|")
    if len(parts) != 3 or parts[0] != "vencira_localcheck":
        raise RuntimeError("unexpected Compose project")
    workdir = Path(parts[1])
    if not workdir.is_absolute() or not workdir.is_dir() or workdir.is_symlink():
        raise RuntimeError("missing or unsafe working directory")
    # The working directory and manifest files come from Docker metadata,
    # never from untrusted arguments.
    names = ["compose.yaml", "compose.preview.yaml"]
    paths = [Path(p.strip()) for p in parts[2].split(",")]
    if len(paths) != 2 or any(p.name not in names for p in paths):
        raise RuntimeError("unexpected Compose manifest inventory")
    if set(p.name for p in paths) != set(names):
        raise RuntimeError("Compose manifest pair mismatch")
    if any(not p.is_absolute() or p.parent != workdir for p in paths):
        raise RuntimeError("manifest location outside known working directory")
    for p in paths:
        secure_regular(p)
        mark(p.name.replace(".", "_").upper() + "_PRESENT", "YES")
    mark("COMPOSE_TWO_FILES_PRESENT", "PASS")
    mark("COMPOSE_CONTENT_PRINTED", "NO")
    # Record only service state, never ExecStart, Environment or unit content.
    status = run(["systemctl", "is-active", "caddy"])
    if status != "active":
        raise RuntimeError("Caddy unit not active")
    mark("CADDY_UNIT_ACTIVE", "PASS")
    # Checking /etc/caddy/Caddyfile existence is NOT verification that it is
    # loaded; Caddy may use another config path. Do not pretend otherwise.
    mark("CADDY_ACTIVE_CONFIG_VERIFIED", "NO")
    mark("COMPOSE_INTERPOLATION_REVIEWED", "NO")
    mark("HTTPS_CANDIDATE_TESTED", "NO")
    mark("ROLLBACK_TESTED", "NO")
    mark("RESULT", 0)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError):
        mark("RESULT", 1)
        raise SystemExit(1)
