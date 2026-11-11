#!/usr/bin/env python3
"""D3-B3: offline verification of a previously saved Docker archive, no Docker calls."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tarfile

def marker(key, value):
    print(f"D3B3_{key}={value}", flush=True)

def fail(stage, code=3):
    marker(stage, "FAIL")
    marker("IMAGE_LOAD_EXECUTED", "NO")
    marker("ROLLBACK_EXECUTED", "NO")
    marker("RESULT", code)
    raise SystemExit(code)

def main():
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    marker("DEPLOY_EXECUTED", "NO")
    marker("LIVE_MIGRATIONS_EXECUTED", "NO")
    marker("LIVE_RESTORE_EXECUTED", "NO")
    marker("IMAGE_LOAD_EXECUTED", "NO")
    marker("ROLLBACK_EXECUTED", "NO")
    if len(sys.argv) != 2:
        fail("ARCHIVE_ARGUMENT")
    root = Path(sys.argv[1]).absolute()
    try:
        if root.is_symlink() or not root.is_dir():
            fail("ARCHIVE_DIRECTORY")
        if root.stat().st_uid != os.getuid() or root.stat().st_mode & 0o077:
            fail("ARCHIVE_PERMISSIONS")
        archive = root / "images.tar.gz"
        checksum = root / "images.tar.gz.sha256"
        manifest = root / "images.manifest"
        for p in (archive, checksum, manifest):
            if not p.is_file() or p.is_symlink():
                fail("ARCHIVE_FILES")
            if p.stat().st_uid != os.getuid() or p.stat().st_mode & 0o077:
                fail("ARCHIVE_FILE_PERMISSIONS")
        lines = manifest.read_text(encoding="ascii").splitlines()
        ids = {}
        for line in lines:
            key, sep, value = line.partition("=")
            if not sep or key not in ("api", "db", "web") or key in ids or not re.fullmatch(r"sha256:[a-f0-9]{64}", value):
                fail("MANIFEST")
            ids[key] = value
        if set(ids) != {"api", "db", "web"}:
            fail("MANIFEST")
        marker("IMMUTABLE_MANIFEST", "PASS")
        digest_line = checksum.read_text(encoding="ascii").strip()
        m = re.fullmatch(r"([0-9a-f]{64})  images\.tar\.gz", digest_line)
        if not m:
            fail("CHECKSUM_FORMAT")
        sha = hashlib.sha256()
        with archive.open("rb") as f:
            for block in iter(lambda: f.read(1024 * 1024), b""):
                sha.update(block)
        if sha.hexdigest() != m.group(1):
            fail("CHECKSUM")
        marker("ARCHIVE_CHECKSUM", "PASS")
        with tarfile.open(archive, mode="r:gz") as t:
            members = t.getmembers()
            if not members or any(not m.isfile() or m.name.startswith("/") or ".." in Path(m.name).parts for m in members):
                fail("TAR_SAFETY")
            by_name = {m.name: m for m in members}
            if len(by_name) != len(members):
                fail("DUPLICATE_TAR_MEMBERS")
            if "manifest.json" not in by_name:
                fail("DOCKER_MANIFEST")
            raw = t.extractfile(by_name["manifest.json"])
            if raw is None:
                fail("DOCKER_MANIFEST")
            metadata = json.loads(raw.read(2 * 1024 * 1024))
            if not isinstance(metadata, list):
                fail("DOCKER_MANIFEST")
            config_hashes = set()
            for item in metadata:
                if not isinstance(item, dict):
                    fail("DOCKER_MANIFEST")
                cfg = item.get("Config")
                if not isinstance(cfg, str) or not re.fullmatch(r"[a-f0-9]{64}\.json", cfg):
                    fail("CONFIG_NAME")
                if cfg not in by_name:
                    fail("CONFIG_MISSING")
                config_data = t.extractfile(by_name[cfg])
                if config_data is None:
                    fail("CONFIG_MISSING")
                actual = hashlib.sha256(config_data.read()).hexdigest()
                if cfg != actual + ".json":
                    fail("CONFIG_HASH")
                config_hashes.add("sha256:" + actual)
                layers = item.get("Layers")
                if not isinstance(layers, list) or not all(isinstance(x, str) and x in by_name for x in layers):
                    fail("LAYERS_MISSING")
            if not set(ids.values()).issubset(config_hashes):
                fail("EXPECTED_IMAGE_IDS_MISSING")
        marker("DOCKER_ARCHIVE_CONFIG_IDS", "PASS")
        marker("OFFLINE_ARCHIVE_STRUCTURE", "PASS")
        marker("IMAGE_RELOAD_TESTED", "NO")
        marker("OFF_HOST_COPY_VERIFIED", "NO")
        marker("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
        marker("PUBLIC_RELEASE_AUTHORIZED", "NO")
        marker("RESULT", 0)
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError, tarfile.TarError):
        fail("OFFLINE_ARCHIVE_CHECK")

if __name__ == "__main__":
    main()
