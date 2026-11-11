#!/usr/bin/env python3
"""D3-B7: compare the three immutable live container IDs, Docker image inspect
IDs, and the retained pre-upgrade manifest. Read-only and redacted output.
No export/import, no image mutation, no container start or stop.
"""
import os
from pathlib import Path
import re
import subprocess
import sys

ROLES = {
    "API": "vencira_localcheck-api-1",
    "DB": "vencira_localcheck-db-1",
    "WEB": "vencira_localcheck-web_preview-1",
}
SHA = re.compile(r"sha256:[0-9a-f]{64}\Z")

def emit(key, value):
    print(f"D3B7_{key}={value}", flush=True)

def fail(key):
    emit(key, "FAIL")
    emit("RESULT", 3)
    raise SystemExit(3)

def docker(*args):
    try:
        done = subprocess.run(
            ["sudo", "-n", "docker", *args],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, timeout=30, check=False, text=True,
        )
    except (OSError, subprocess.TimeoutExpired):
        fail("DOCKER_READ")
    if done.returncode:
        fail("DOCKER_READ")
    return done.stdout.strip()

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    for key in ("DEPLOY_EXECUTED", "IMAGE_LOAD_EXECUTED",
                "CONTAINER_RUN_EXECUTED", "LIVE_RESTORE_EXECUTED",
                "OPERATIONAL_ROLLBACK_VERIFIED"):
        emit(key, "NO")
    if len(sys.argv) != 2:
        fail("ARGUMENTS")
    base = Path(sys.argv[1])
    if not base.is_absolute() or base.is_symlink() or not base.is_dir():
        fail("ARCHIVE_PATH")
    if base.stat().st_uid != os.getuid() or base.stat().st_mode & 0o077:
        fail("ARCHIVE_PERMISSIONS")
    path = base / "images.manifest"
    if (not path.is_file() or path.is_symlink() or
            path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077):
        fail("MANIFEST_PERMISSIONS")
    try:
        lines = path.read_text(encoding="ascii").splitlines()
    except (OSError, UnicodeError):
        fail("MANIFEST_READ")
    saved = {}
    for line in lines:
        role, sep, value = line.partition("=")
        if not sep or role not in ("api", "db", "web") or role in saved or not SHA.fullmatch(value):
            fail("MANIFEST_SCHEMA")
        saved[role] = value
    if len(saved) != 3 or len(set(saved.values())) != 3:
        fail("MANIFEST_SCHEMA")
    emit("MANIFEST_SCHEMA", "PASS")

    for role, container in ROLES.items():
        # Explicit template: only image ID and Compose identity, never env.
        project = docker("container", "inspect", "--format",
                         '{{index .Config.Labels "com.docker.compose.project"}}',
                         container)
        running = docker("container", "inspect", "--format", "{{.State.Running}}", container)
        if project != "vencira_localcheck" or running != "true":
            fail("DEV_IDENTITY")
        container_id = docker("container", "inspect", "--format", "{{.Image}}", container)
        if not SHA.fullmatch(container_id):
            fail("CONTAINER_IMAGE_FORMAT")
        image_id = docker("image", "inspect", "--format", "{{.Id}}", container_id)
        if not SHA.fullmatch(image_id):
            fail("IMAGE_INSPECT_ID_FORMAT")
        emit(role + "_CONTAINER_VS_IMAGE_INSPECT", "MATCH" if container_id == image_id else "MISMATCH")
        emit(role + "_CONTAINER_VS_RETAINED_MANIFEST",
             "MATCH" if container_id == saved[role.lower()] else "MISMATCH")
    emit("EXACT_ARCHIVED_CONFIG_ID_VERIFIED", "NO")
    emit("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
    emit("RESULT", 0)

if __name__ == "__main__":
    main()
