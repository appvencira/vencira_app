"""MB1 offline synthetic-package binding for an externally trusted anti-rollback head.

No external head creation/storage, no production usage, and no operational release.
The trusted head and both HMAC keys MUST come from independent custody.
"""
import hashlib
import hmac
import json
import os
import stat
from pathlib import Path

from .offline_antirollback_head_mb1 import (
    AntiRollbackError, make_genesis, issue_successor,
    verify_restore, verify_receipt,
)

_FILES = ("capture.enc", "manifest.json", "manifest.mac")
_LIMITS = {"capture.enc": 192 * 1024 * 1024, "manifest.json": 8192, "manifest.mac": 128}


def _guard():
    if os.getenv("VENCIRA_ENV") != "test" or os.getenv("MB1_DISPOSABLE_ONLY") != "1":
        raise AntiRollbackError("SYNTHETIC_ONLY")


def _read(root, name):
    path = root / name
    fd = None
    try:
        fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | getattr(os, "O_NOFOLLOW", 0))
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or
                info.st_nlink != 1 or not 0 < info.st_size <= _LIMITS[name]):
            raise AntiRollbackError("UNSAFE_PACKAGE_FILE")
        with os.fdopen(fd, "rb") as stream:
            fd = None
            data = stream.read(_LIMITS[name] + 1)
        if len(data) > _LIMITS[name]:
            raise AntiRollbackError("OVERSIZED_PACKAGE_FILE")
        return data
    except OSError as exc:
        raise AntiRollbackError("UNREADABLE_PACKAGE_FILE") from exc
    finally:
        if fd is not None:
            os.close(fd)


def _package(root, manifest_key):
    _guard()
    if type(manifest_key) is not bytes or len(manifest_key) < 32:
        raise AntiRollbackError("INVALID_MANIFEST_KEY")
    root = Path(root)
    if (root.is_symlink() or not root.is_dir() or
            root.stat().st_mode & 0o077):
        raise AntiRollbackError("UNSAFE_PACKAGE_DIRECTORY")
    parts = {name: _read(root, name) for name in _FILES}
    actual_mac = hmac.new(
        manifest_key, parts["manifest.json"], hashlib.sha256
    ).hexdigest().encode("ascii")
    if not hmac.compare_digest(actual_mac, parts["manifest.mac"]):
        raise AntiRollbackError("MANIFEST_AUTHENTICATION_FAILED")
    try:
        manifest = json.loads(parts["manifest.json"])
    except (UnicodeError, ValueError) as exc:
        raise AntiRollbackError("INVALID_PACKAGE_MANIFEST") from exc
    if type(manifest) is not dict or type(manifest.get("snapshot")) is not str:
        raise AntiRollbackError("INVALID_PACKAGE_MANIFEST")
    if type(manifest.get("envelope_sha256")) is not str or (
            not hmac.compare_digest(
                hashlib.sha256(parts["capture.enc"]).hexdigest(),
                manifest["envelope_sha256"])):
        raise AntiRollbackError("ENVELOPE_MANIFEST_MISMATCH")
    # Exact ordered framing of all three physical package components.
    framed = bytearray(b"MB1-PACKAGE-THREE-FILES-v1\0")
    for name in _FILES:
        data = parts[name]
        framed.extend(name.encode("ascii") + b"\0")
        framed.extend(len(data).to_bytes(8, "big"))
        framed.extend(hashlib.sha256(data).digest())
    return manifest["snapshot"], bytes(framed)


def issue_package_receipt(root, *, manifest_key, receipt_key, trusted_previous_head=None):
    """Return a candidate receipt; caller separately verifies and stores head."""
    snapshot, package_binding = _package(root, manifest_key)
    if trusted_previous_head is None:
        return make_genesis(snapshot, package_binding, receipt_key)
    return issue_successor(trusted_previous_head, snapshot, package_binding, receipt_key)


def verify_package_antirollback(root, *, manifest_key, receipt_key,
                                candidate_receipt, trusted_external_head):
    snapshot, package_binding = _package(root, manifest_key)
    result = verify_restore(
        trusted_external_head, candidate_receipt, package_binding, receipt_key
    )
    payload = verify_receipt(candidate_receipt, receipt_key)
    if payload["snapshot_id"] != snapshot:
        raise AntiRollbackError("PACKAGE_SNAPSHOT_IDENTITY_MISMATCH")
    return result
