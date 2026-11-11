#!/usr/bin/env python3
"""D4-D: read-only archived image role and launch-contract inventory.

Uses the established D3-B4 rootfs/platform mapping. Never prints image IDs,
environment values, labels or full launch commands. No image import or runtime.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tarfile

ROLES = {"api": "vencira_localcheck-api-1",
         "db": "vencira_localcheck-db-1",
         "web": "vencira_localcheck-web_preview-1"}

def mark(k, v):
    print(f"D4D_{k}={v}", flush=True)

def fail(k):
    mark(k, "FAIL")
    mark("RESULT", 3)
    raise SystemExit(3)

def inspect(kind, target):
    try:
        p = subprocess.run(["sudo", "-n", "docker", kind, "inspect", target],
                           stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, timeout=30, check=False)
        if p.returncode:
            fail("DOCKER_INSPECT")
        data = json.loads(p.stdout)
        if not isinstance(data, list) or len(data) != 1:
            fail("DOCKER_INSPECT_FORMAT")
        return data[0]
    except (OSError, ValueError, subprocess.TimeoutExpired):
        fail("DOCKER_INSPECT")

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for name in ("DEPLOY_EXECUTED", "HOST_DOCKER_IMAGE_LOAD_EXECUTED",
                 "CONTAINER_RUN_EXECUTED", "LIVE_RESTORE_EXECUTED",
                 "OPERATIONAL_ROLLBACK_EXECUTED"):
        mark(name, "NO")
    if len(sys.argv) != 2:
        fail("ARGUMENT")
    root = Path(sys.argv[1])
    if (not root.is_absolute() or root.is_symlink() or not root.is_dir()
            or root.stat().st_uid != os.getuid()
            or root.stat().st_mode & 0o077):
        fail("ARCHIVE_PERMISSIONS")
    manifest_path = root / "images.manifest"
    archive = root / "images.tar.gz"
    for p in (manifest_path, archive):
        if (not p.is_file() or p.is_symlink() or
                p.stat().st_uid != os.getuid() or p.stat().st_mode & 0o077):
            fail("ARCHIVE_PERMISSIONS")
    try:
        saved_ids = {}
        for line in manifest_path.read_text(encoding="ascii").splitlines():
            role, delim, ident = line.partition("=")
            if (not delim or role not in ROLES or role in saved_ids or
                    re.fullmatch(r"sha256:[a-f0-9]{64}", ident) is None):
                fail("MANIFEST_SCHEMA")
            saved_ids[role] = ident
        if len(saved_ids) != 3:
            fail("MANIFEST_SCHEMA")
        mark("MANIFEST_SCHEMA", "PASS")
        live = {}
        for role, container in ROLES.items():
            info = inspect("container", container)
            if (not info.get("State", {}).get("Running") or
                info.get("Config", {}).get("Labels", {}).get(
                    "com.docker.compose.project") != "vencira_localcheck" or
                info.get("Image") != saved_ids[role]):
                fail("LIVE_IDENTITY")
            live[role] = inspect("image", saved_ids[role])
        mark("LIVE_IDENTITY", "PASS")

        with tarfile.open(archive, "r:gz") as t:
            entries = t.getmembers()
            by_name = {m.name: m for m in entries}
            if len(entries) != len(by_name) or "manifest.json" not in by_name:
                fail("TAR_METADATA")
            mf = t.extractfile(by_name["manifest.json"])
            listing = json.load(mf) if mf is not None else None
            if not isinstance(listing, list) or len(listing) != 3:
                fail("ARCHIVE_CONFIG_COUNT")
            configs = []
            for e in listing:
                cfg = e.get("Config") if isinstance(e, dict) else None
                if not isinstance(cfg, str) or not re.fullmatch(
                    r"(?:[a-f0-9]{64}\.json|blobs/sha256/[a-f0-9]{64})", cfg
                ) or cfg not in by_name or not by_name[cfg].isfile():
                    fail("ARCHIVE_CONFIG")
                f = t.extractfile(by_name[cfg])
                obj = json.load(f) if f else None
                if not isinstance(obj, dict):
                    fail("ARCHIVE_CONFIG")
                configs.append(obj)
        mark("ARCHIVED_CONFIGS", len(configs))
        used = set()
        for role in ROLES:
            current = live[role]
            roots = current.get("RootFS", {}).get("Layers")
            matches = [
                (i, c) for i, c in enumerate(configs)
                if isinstance(roots, list)
                and c.get("rootfs", {}).get("diff_ids") == roots
                and c.get("architecture") == current.get("Architecture")
                and c.get("os") == current.get("Os")
            ]
            mark(role.upper() + "_ROOTFS_PLATFORM_MATCH_COUNT", len(matches))
            if len(matches) != 1 or matches[0][0] in used:
                fail("UNIQUE_ROLE_MAPPING")
            used.add(matches[0][0])
            cfg = matches[0][1].get("config") or {}
            mark(role.upper() + "_LAUNCH_ENTRYPOINT_PRESENT",
                 "YES" if cfg.get("Entrypoint") else "NO")
            mark(role.upper() + "_LAUNCH_CMD_PRESENT",
                 "YES" if cfg.get("Cmd") else "NO")
            mark(role.upper() + "_CONFIG_ENV_KEYS_PRESENT",
                 "YES" if cfg.get("Env") else "NO")
        mark("UNIQUE_ROLE_MAPPING", "PASS")
        mark("API_WEB_STARTUP_VERIFIED", "NO")
        mark("O5_IMAGE_COMPATIBILITY_VERIFIED", "NO")
        mark("EXACT_HISTORICAL_ID_VERIFIED", "NO")
        mark("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
        mark("PUBLIC_RELEASE_AUTHORIZED", "NO")
        mark("RESULT", 0)
    except (OSError, ValueError, TypeError, UnicodeError, tarfile.TarError):
        fail("METADATA_READ")

if __name__ == "__main__":
    main()
