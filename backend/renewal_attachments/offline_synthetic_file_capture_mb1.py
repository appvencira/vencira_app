"""MB1: physical synthetic file capture under cross-process cooperative fence.

This captures a *test fixture* with a DB-inventory-shaped JSON file and
cipher/journal bytes. It is NOT a PostgreSQL snapshot, and noncooperative
processes are not prevented from writing. Never use with operational data.
"""
import hashlib
import json
import os
from pathlib import Path

from .offline_multiprocess_fence_mb1 import IsolatedProcessFence
from .offline_capture_set_b18e import verify_capture_set


class SyntheticFileCaptureError(RuntimeError):
    pass


def _read_file(path, limit):
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise SyntheticFileCaptureError("FILE_MISSING_OR_SYMLINK")
    raw = path.read_bytes()
    if not raw or len(raw) > limit:
        raise SyntheticFileCaptureError("BAD_FILE_SIZE")
    return raw


def capture_synthetic_files(*, fence, root, snapshot, epoch):
    """Require an explicit writer registry outside this isolated test fixture."""
    if not isinstance(fence, IsolatedProcessFence):
        raise SyntheticFileCaptureError("UNKNOWN_FENCE")
    if type(epoch) is not int or epoch < 0 or type(snapshot) is not str or not snapshot:
        raise SyntheticFileCaptureError("INVALID_CAPTURE_ID")
    root = Path(root)
    if root.is_symlink() or not root.is_dir() or root.stat().st_mode & 0o077:
        raise SyntheticFileCaptureError("UNSAFE_ROOT")
    with fence.capture():
        record_bytes = _read_file(root / "db_inventory.json", 1024 * 1024)
        try:
            db = json.loads(record_bytes)
        except (TypeError, ValueError) as exc:
            raise SyntheticFileCaptureError("BAD_INVENTORY") from exc
        if type(db) is not dict or len(db) != 1:
            raise SyntheticFileCaptureError("INCOMPLETE_INVENTORY")
        key = next(iter(db))
        if type(key) is not str or len(key) != 32:
            raise SyntheticFileCaptureError("INVALID_OBJECT_ID")
        obj = _read_file(root / "objects" / key, 16 * 1024 * 1024)
        journal = _read_file(root / "journal" / (key + ".json"), 4096)
        digest = hashlib.sha256(json.dumps(
            db, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        marker = dict(epoch=epoch, snapshot=snapshot, inventory_sha256=digest)
        result = verify_capture_set(
            before=marker, after=marker, db_records=db,
            encrypted_objects={key: obj}, journals={key: journal},
            drained=True, missing_writers=())
        # This only attests internal consistency of a fixture; NOT snapshot age,
        # independent authenticity or a database/filesystem atomic boundary.
        return result
