#!/usr/bin/env python3
"""D3-B6 content-integrity gate, read-only, streamed OCI archive audit.

Reads a .tar.gz once and hashes OCI blobs without extracting files. No Docker,
Podman, containers, permissions, PostgreSQL or network operations.
"""
import hashlib
import json
import re
import sys
import tarfile
from pathlib import Path

PAT = re.compile(r"blobs/sha256/([0-9a-f]{64})\Z")
CHUNK = 1024 * 1024
MAX_METADATA = 4 * CHUNK

def mark(name, value):
    print(f"D3B6C_{name}={value}", flush=True)

def fail(name):
    mark(name, "FAIL")
    mark("RESULT", 1)
    raise SystemExit(1)

def run(path):
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        fail("ARCHIVE_PATH")

    observed = {}
    meta = {}
    blob_count = 0
    try:
        with tarfile.open(path, mode="r|gz") as archive:
            for entry in archive:
                name = entry.name
                digest_match = PAT.fullmatch(name)
                metadata = name in ("index.json", "manifest.json", "oci-layout")
                if not digest_match and not metadata:
                    continue
                if not entry.isfile():
                    fail("ENTRY_TYPE")
                if name in observed or name in meta:
                    fail("DUPLICATE_ENTRY")
                stream = archive.extractfile(entry)
                if stream is None:
                    fail("ENTRY_READ")
                if metadata:
                    if entry.size > MAX_METADATA:
                        fail("METADATA_SIZE")
                    meta[name] = json.loads(stream.read(MAX_METADATA + 1))
                    continue
                expected = digest_match.group(1)
                digest = hashlib.sha256()
                bytes_read = 0
                while True:
                    chunk = stream.read(CHUNK)
                    if not chunk:
                        break
                    bytes_read += len(chunk)
                    digest.update(chunk)
                if bytes_read != entry.size or digest.hexdigest() != expected:
                    fail("BLOB_SHA256")
                observed[name] = bytes_read
                blob_count += 1
    except (OSError, tarfile.TarError, UnicodeError, ValueError, json.JSONDecodeError, EOFError):
        fail("ARCHIVE_READ")

    if not all(k in meta for k in ("index.json", "manifest.json", "oci-layout")):
        fail("METADATA")
    mark("METADATA", "PASS")
    if meta["oci-layout"] != {"imageLayoutVersion": "1.0.0"}:
        fail("OCI_LAYOUT")
    index = meta["index.json"]
    descriptors = index.get("manifests") if isinstance(index, dict) else None
    if not isinstance(descriptors, list) or not descriptors:
        fail("INDEX_SCHEMA")
    for item in descriptors:
        if not isinstance(item, dict):
            fail("INDEX_SCHEMA")
        digest = item.get("digest")
        size = item.get("size")
        if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            fail("INDEX_SCHEMA")
        if type(size) is not int or size < 0:
            fail("INDEX_SCHEMA")
        blob_path = "blobs/sha256/" + digest.removeprefix("sha256:")
        if observed.get(blob_path) != size:
            fail("INDEX_BLOB_REFERENCE")
    mark("INDEX_BLOB_REFERENCES", "PASS")
    mark("OCI_BLOB_SHA256", "PASS")
    mark("OCI_BLOBS_HASHED", blob_count)
    mark("OCI_INDEX_DESCRIPTORS", len(descriptors))
    mark("EXACT_HISTORICAL_IMAGE_ID_VERIFIED", "NO")
    mark("O5_COMPATIBILITY_VERIFIED", "NO")
    mark("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
    mark("HOST_DOCKER_IMAGE_LOAD_EXECUTED", "NO")
    mark("CONTAINER_RUN_EXECUTED", "NO")
    mark("LIVE_RESTORE_EXECUTED", "NO")
    mark("RESULT", 0)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        fail("ARGUMENTS")
    run(Path(sys.argv[1]))
