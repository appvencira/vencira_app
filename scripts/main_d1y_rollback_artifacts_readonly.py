#!/usr/bin/env python3
"""D1-Y: read-only pre-rollback inventory, no credentials or image IDs printed.

Tests *availability* of currently running images, and existence of persistent
Postgres volume. Does not prove previous version retention or run a rollback.
"""
import json
import os
import subprocess
import sys


SERVICES = ("api", "db", "web_preview")
PREFIX = "vencira_localcheck-"


def mark(k, v):
    print(f"D1Y_ROLLBACK_{k}={v}", flush=True)


def docker(*args):
    command = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    process = subprocess.run(command + list(args), text=True, capture_output=True,
                             timeout=20, check=False)
    if process.returncode:
        raise RuntimeError("Docker inspection unavailable")
    return process.stdout.strip()


def main():
    mark("READ_ONLY", "YES")
    mark("CONFIG_OR_SECRETS_PRINTED", "NO")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_RESTORE_EXECUTED", "NO")
    records = []
    for service in SERVICES:
        raw = docker("inspect", "--type", "container", f"{PREFIX}{service}-1")
        data = json.loads(raw)
        if len(data) != 1:
            raise ValueError("unexpected container count")
        item = data[0]
        if item.get("Config", {}).get("Labels", {}).get(
                "com.docker.compose.project") != "vencira_localcheck":
            raise ValueError("wrong Compose project")
        if not item.get("State", {}).get("Running"):
            raise ValueError("service stopped")
        image_id = item.get("Image", "")
        if not image_id.startswith("sha256:"):
            raise ValueError("unresolved running image")
        # Local inspect by immutable digest, not mutable tag name.
        image = json.loads(docker("image", "inspect", image_id))
        if len(image) != 1 or image[0].get("Id") != image_id:
            raise ValueError("running image not locally present")
        records.append((service, item))
        mark(service.upper() + "_RUNNING_IMAGE_PRESENT", "PASS")
    db = next(item for service, item in records if service == "db")
    mounts = db.get("Mounts", [])
    database_mounts = [m for m in mounts
                       if m.get("Destination") == "/var/lib/postgresql/data"]
    if len(database_mounts) != 1 or database_mounts[0].get("Type") != "volume":
        raise ValueError("Postgres persistence not verified")
    mark("DB_NAMED_VOLUME_PRESENT", "PASS")
    # No assertion about the existence of a pre-update or older image.
    mark("PREVIOUS_RELEASE_IMAGES_VERIFIED", "NO")
    mark("ROLLBACK_ARTIFACT_SET_COMPLETE", "NO")
    mark("POST_UPDATE_WRITE_LOSS_POLICY_DEFINED", "NO")
    mark("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
    mark("RESULT", 0)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, ValueError, KeyError, TypeError, OSError,
            subprocess.TimeoutExpired, json.JSONDecodeError):
        mark("RESULT", 1)
        sys.exit(1)
