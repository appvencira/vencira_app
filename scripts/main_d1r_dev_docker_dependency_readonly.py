#!/usr/bin/env python3
"""D1-R: read-only classification of current DEV Docker service dependencies.

Never prints environment, bind source/destination, host path, port numbers,
network names, credentials, labels or container logs. No Docker writes.
"""
import json
import os
import subprocess
import sys

SERVICES = {
    "API": "vencira_localcheck-api-1",
    "DB": "vencira_localcheck-db-1",
    "WEB": "vencira_localcheck-web_preview-1",
}


def mark(key, value):
    print(f"D1R_{key}={value}", flush=True)


def docker_inspect(name):
    command = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    try:
        result = subprocess.run(
            command + ["inspect", "--type=container", name],
            capture_output=True, text=True, timeout=25, check=False,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        raise RuntimeError("docker inspect unavailable") from exc
    if result.returncode:
        raise RuntimeError("docker inspect failed")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError("invalid inspect response") from exc
    if not isinstance(payload, list) or len(payload) != 1:
        raise RuntimeError("unexpected inspect cardinality")
    return payload[0]


def main():
    mark("READ_ONLY", "YES")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    observed_ids = set()
    for label, name in SERVICES.items():
        data = docker_inspect(name)
        labels = data.get("Config", {}).get("Labels") or {}
        if labels.get("com.docker.compose.project") != "vencira_localcheck":
            raise RuntimeError("project identity mismatch")
        if data.get("State", {}).get("Status") != "running":
            raise RuntimeError("service not running")
        image_id = data.get("Image")
        if not isinstance(image_id, str) or not image_id.startswith("sha256:"):
            raise RuntimeError("image digest unavailable")
        cid = data.get("Id")
        if not isinstance(cid, str) or len(cid) < 20 or cid in observed_ids:
            raise RuntimeError("invalid container identity")
        observed_ids.add(cid)
        mounts = data.get("Mounts") or []
        if not isinstance(mounts, list):
            raise RuntimeError("unexpected mounts schema")
        bind_count = sum(m.get("Type") == "bind" for m in mounts)
        volume_count = sum(m.get("Type") == "volume" for m in mounts)
        tmpfs_count = sum(m.get("Type") == "tmpfs" for m in mounts)
        unknown_count = len(mounts) - bind_count - volume_count - tmpfs_count
        host = data.get("HostConfig") or {}
        if unknown_count:
            raise RuntimeError("unknown mount type")
        mark(f"{label}_PROJECT", "PASS")
        mark(f"{label}_IMAGE_DIGEST_PRESENT", "YES")
        mark(f"{label}_BIND_MOUNT_COUNT", bind_count)
        mark(f"{label}_NAMED_VOLUME_MOUNT_COUNT", volume_count)
        mark(f"{label}_TMPFS_MOUNT_COUNT", tmpfs_count)
        mark(f"{label}_RESTART_POLICY_PRESENT",
             "YES" if (host.get("RestartPolicy") or {}).get("Name") not in (None, "", "no") else "NO")
        mark(f"{label}_PUBLISHED_PORTS_PRESENT",
             "YES" if any((host.get("PortBindings") or {}).values()) else "NO")
        mark(f"{label}_READONLY_ROOTFS", "YES" if host.get("ReadonlyRootfs") is True else "NO")
    mark("THREE_DISTINCT_LIVE_CONTAINERS", "PASS")
    mark("COMPOSE_MANIFEST_CONTENT_READ", "NO")
    mark("CADDY_CONFIG_CONTENT_READ", "NO")
    mark("ROLLBACK_EXECUTED", "NO")
    mark("ROLLBACK_VERIFIED", "NO")
    mark("RESULT", 0)


if __name__ == "__main__":
    try:
        main()
    except RuntimeError:
        mark("RESULT", 1)
        sys.exit(1)
