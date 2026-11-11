#!/usr/bin/env python3
"""D3-B6 read-only inventory of Docker/OCI metadata in an existing image archive.

Never extracts files, invokes Docker/Podman, or prints original image identifiers.
This is a structural preflight, NOT a proof of historical image identity.
"""
import json
import re
import sys
import tarfile
from pathlib import Path

def mark(k, v):
    print(f"D3B6_{k}={v}", flush=True)

def fail(k):
    mark(k, "FAIL")
    mark("RESULT", 1)
    raise SystemExit(1)

if len(sys.argv) != 2:
    fail("ARGUMENTS")
archive = Path(sys.argv[1])
if not archive.is_absolute() or not archive.is_file() or archive.is_symlink():
    fail("ARCHIVE_PATH")

names = ("manifest.json", "index.json", "oci-layout")
payload = {}
try:
    with tarfile.open(archive, mode="r|gz") as tf:
        for entry in tf:
            if entry.name not in names:
                continue
            if entry.name in payload or not entry.isfile() or entry.size > 4 * 1024 * 1024:
                fail("METADATA_ENTRY")
            extracted = tf.extractfile(entry)
            if extracted is None:
                fail("METADATA_ENTRY")
            payload[entry.name] = json.load(extracted)
except (OSError, tarfile.TarError, ValueError, UnicodeError, json.JSONDecodeError):
    fail("ARCHIVE_READ")
if set(payload) != set(names):
    fail("METADATA_PRESENCE")
mark("METADATA_PRESENCE", "PASS")

manifest, index, layout = (payload[n] for n in names)
if not isinstance(manifest, list) or not isinstance(index, dict) or not isinstance(layout, dict):
    fail("METADATA_SCHEMA")
if layout.get("imageLayoutVersion") != "1.0.0":
    fail("OCI_LAYOUT")
mark("OCI_LAYOUT", "PASS")

if not manifest or any(
    not isinstance(item, dict) or not isinstance(item.get("Config"), str)
    or not isinstance(item.get("Layers"), list)
    or any(not isinstance(layer, str) for layer in item["Layers"])
    for item in manifest
):
    fail("DOCKER_MANIFEST_SCHEMA")
mark("DOCKER_MANIFEST_SCHEMA", "PASS")
mark("DOCKER_MANIFEST_ENTRIES", len(manifest))
mark("DOCKER_CONFIG_REFERENCES", len(set(item["Config"] for item in manifest)))
mark("DOCKER_LAYER_REFERENCES", sum(len(item["Layers"]) for item in manifest))
mark("DOCKER_REPO_TAGS_PRESENT", "YES" if any(item.get("RepoTags") for item in manifest) else "NO")

descriptors = index.get("manifests")
if not isinstance(descriptors, list) or not descriptors or any(
    not isinstance(d, dict) or not isinstance(d.get("digest"), str)
    or not re.fullmatch(r"sha256:[0-9a-f]{64}", d["digest"])
    or not isinstance(d.get("size"), int) or d["size"] < 0
    for d in descriptors
):
    fail("OCI_INDEX_SCHEMA")
mark("OCI_INDEX_SCHEMA", "PASS")
mark("OCI_INDEX_DESCRIPTORS", len(descriptors))
mark("EXACT_HISTORICAL_IMAGE_ID_VERIFIED", "NO")
mark("BLOB_DIGEST_CONTENT_VERIFIED", "NO")
mark("O5_COMPATIBILITY_VERIFIED", "NO")
mark("OPERATIONAL_ROLLBACK_VERIFIED", "NO")
mark("HOST_DOCKER_IMAGE_LOAD_EXECUTED", "NO")
mark("CONTAINER_RUN_EXECUTED", "NO")
mark("LIVE_RESTORE_EXECUTED", "NO")
mark("RESULT", 0)
