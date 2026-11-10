#!/usr/bin/env python3
"""D1-U: confidential static review of live Compose effective declarations.

Do not print config, values, paths, labels, port numbers or secrets. This is
read-only; captures Docker Compose JSON only in memory. No deploy/DB operations.
"""
import json
import os
from pathlib import Path
import subprocess


def mark(k, v):
    print(f"D1U_COMPOSE_{k}={v}", flush=True)


def run(args):
    process = subprocess.run(args, text=True, capture_output=True,
                             timeout=40, check=False)
    if process.returncode:
        raise RuntimeError("compose metadata check failed")
    return process.stdout


def main():
    command = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    template = (
        '{{index .Config.Labels "com.docker.compose.project"}}|'
        '{{index .Config.Labels "com.docker.compose.project.working_dir"}}|'
        '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
    )
    parts = run(command + ["inspect", "-f", template,
                           "vencira_localcheck-api-1"]).strip().split("|")
    if len(parts) != 3 or parts[0] != "vencira_localcheck":
        raise RuntimeError("unexpected project")
    root = Path(parts[1])
    files = [Path(f.strip()) for f in parts[2].split(",")]
    if not root.is_absolute() or root.is_symlink() or not root.is_dir():
        raise RuntimeError("unexpected Compose directory")
    if len(files) != 2 or {f.name for f in files} != {
            "compose.yaml", "compose.preview.yaml"}:
        raise RuntimeError("unexpected Compose files")
    if any(f.parent != root or f.is_symlink() or not f.is_file() for f in files):
        raise RuntimeError("unexpected Compose location")
    # Never print Compose's rendered result: even a diagnostic may contain
    # credentials. --no-env-resolution prevents reading env_file values.
    args = command + ["compose"]
    for file in files:
        args += ["-f", str(file)]
    args += ["--project-directory", str(root), "config",
             "--no-interpolate", "--no-env-resolution", "--format", "json"]
    raw = run(args)
    try:
        cfg = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError("invalid Compose JSON") from exc
    if not isinstance(cfg, dict):
        raise RuntimeError("unexpected Compose structure")
    services = cfg.get("services")
    if not isinstance(services, dict):
        raise RuntimeError("missing services")
    # Only known DEV services must be present; fail closed on new ones.
    expected = {"api", "db", "web_preview"}
    if set(services) != expected:
        raise RuntimeError("unexpected Compose services")
    mark("SERVICE_NAMES", "PASS")
    for name in sorted(expected):
        svc = services[name]
        if not isinstance(svc, dict):
            raise RuntimeError("invalid service definition")
        if svc.get("privileged") is True or svc.get("network_mode") == "host":
            raise RuntimeError("unsafe container elevation or host network")
        if svc.get("pid") == "host" or svc.get("ipc") == "host":
            raise RuntimeError("host namespace usage")
        mounts = svc.get("volumes") or []
        if not isinstance(mounts, list):
            raise RuntimeError("unknown volume declaration")
        if name == "db" and not mounts:
            raise RuntimeError("database persistence not declared")
        mark(name.upper() + "_STATIC_POLICY", "PASS")
    mark("DB_VOLUME_DECLARED", "YES")
    mark("CONFIG_VALUES_PRINTED", "NO")
    mark("CADDY_EFFECTIVE_CONFIG_VERIFIED", "NO")
    mark("ROLLBACK_VERIFIED", "NO")
    mark("RESULT", 0)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired):
        mark("RESULT", 1)
        raise SystemExit(1)
