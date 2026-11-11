#!/usr/bin/env python3
"""D3-B4 diagnosis: compare archived config/rootfs with running image metadata, read-only."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile

ROLES = {"api": "vencira_localcheck-api-1", "db": "vencira_localcheck-db-1", "web": "vencira_localcheck-web_preview-1"}
FIELDS = ("Env", "Cmd", "Entrypoint", "WorkingDir", "User", "ExposedPorts", "Volumes", "Labels", "Healthcheck", "StopSignal", "OnBuild", "Shell")

def mark(k, v):
    print(f"D3B4_{k}={v}", flush=True)

def fail(k):
    mark(k, "FAIL")
    mark("RESULT", 3)
    raise SystemExit(3)

def inspect(kind, target):
    p = subprocess.run(["sudo", "-n", "docker", kind, "inspect", target], capture_output=True, timeout=30, check=False)
    if p.returncode != 0:
        fail("DOCKER_METADATA_READ")
    try:
        value = json.loads(p.stdout)
        if not isinstance(value, list) or len(value) != 1:
            fail("DOCKER_METADATA_PARSE")
        return value[0]
    except ValueError:
        fail("DOCKER_METADATA_PARSE")

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for k in ("DEPLOY_EXECUTED", "LIVE_MIGRATIONS_EXECUTED", "LIVE_RESTORE_EXECUTED", "IMAGE_LOAD_EXECUTED", "ROLLBACK_EXECUTED"):
        mark(k, "NO")
    if len(sys.argv) != 2:
        fail("ARCHIVE_ARGUMENT")
    root = Path(sys.argv[1]).absolute()
    if root.is_symlink() or not root.is_dir() or root.stat().st_uid != os.getuid() or root.stat().st_mode & 0o077:
        fail("ARCHIVE_PERMISSIONS")
    try:
        ids = {}
        for line in (root / "images.manifest").read_text(encoding="ascii").splitlines():
            role, sep, ident = line.partition("=")
            if not sep or role in ids or role not in ROLES or not re.fullmatch(r"sha256:[a-f0-9]{64}", ident):
                fail("MANIFEST")
            ids[role] = ident
        if set(ids) != set(ROLES):
            fail("MANIFEST")
        live = {}
        for role, name in ROLES.items():
            container = inspect("container", name)
            if not container.get("State", {}).get("Running") or container.get("Config", {}).get("Labels", {}).get("com.docker.compose.project") != "vencira_localcheck":
                fail("DEV_IDENTITY")
            if container.get("Image") != ids[role]:
                fail("DEV_IMAGE_CHANGED_SINCE_ARCHIVE")
            live[role] = inspect("image", ids[role])
        mark("DEV_IMMUTABLE_IDENTITY", "PASS")
        path = root / "images.tar.gz"
        if path.is_symlink() or not path.is_file() or path.stat().st_mode & 0o077:
            fail("ARCHIVE_PERMISSIONS")
        configs = []
        with tarfile.open(path, "r:gz") as arc:
            members = {m.name: m for m in arc.getmembers()}
            if "manifest.json" not in members:
                fail("ARCHIVE_MANIFEST")
            f = arc.extractfile(members["manifest.json"])
            metadata = json.load(f) if f is not None else None
            if not isinstance(metadata, list) or not metadata:
                fail("ARCHIVE_MANIFEST")
            for item in metadata:
                name = item.get("Config") if isinstance(item, dict) else None
                if not isinstance(name, str) or name not in members or not members[name].isfile():
                    fail("ARCHIVE_CONFIG")
                f = arc.extractfile(members[name])
                value = json.load(f) if f is not None else None
                if not isinstance(value, dict):
                    fail("ARCHIVE_CONFIG")
                configs.append(value)
        mark("ARCHIVE_CONFIG_COUNT", len(configs))
        for role in ROLES:
            current = live[role]
            roots = current.get("RootFS", {}).get("Layers")
            matches = [c for c in configs if c.get("rootfs", {}).get("diff_ids") == roots
                       and c.get("architecture") == current.get("Architecture")
                       and c.get("os") == current.get("Os")
                       and isinstance(roots, list)]
            name = "EXPECTED_" + role.upper()
            mark(name + "_ROOTFS_PLATFORM_MATCH_COUNT", len(matches))
            if len(matches) == 1:
                saved = matches[0].get("config") or {}
                original = current.get("Config") or {}
                common = [f for f in FIELDS if f in saved and f in original]
                mark(name + "_RUNTIME_FIELDS_COMPARED", len(common))
                mark(name + "_RUNTIME_FIELDS_DIFFERENT",
                     sum(saved[f] != original[f] for f in common))
            else:
                mark(name + "_RUNTIME_FIELDS_COMPARED", "NOT_CHECKED")
                mark(name + "_RUNTIME_FIELDS_DIFFERENT", "NOT_CHECKED")
        mark("ARCHIVE_EXACT_IMAGE_IDS_VERIFIED", "NO")
        mark("IMAGE_RELOAD_TESTED", "NO")
        mark("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
        mark("RESULT", 0)
    except (OSError, ValueError, TypeError, tarfile.TarError, subprocess.TimeoutExpired):
        fail("DIAGNOSTIC_READ")

if __name__ == "__main__":
    main()
