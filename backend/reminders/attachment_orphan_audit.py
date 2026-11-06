"""Read-only offline audit for encrypted quarantine objects.

No deletion, decryption, DB queries, or HTTP exposure. The caller supplies a
snapshot of authorized UUID references from one consistent database snapshot.
"""
import os
import stat
import uuid
from dataclasses import dataclass
from pathlib import Path

from .attachment_private_store import PrivateStoreError

MAX_INVENTORY_ENTRIES = 100_000


@dataclass(frozen=True)
class QuarantineAudit:
    objects_checked: int
    referenced: int
    orphans: tuple[str, ...]
    missing: tuple[str, ...]
    unsafe: tuple[str, ...]
    deletion_authorized: bool = False


def audit_private_quarantine(*, root: Path, referenced_keys):
    root = Path(root)
    if root.is_symlink() or not root.is_dir() or root.stat().st_mode & 0o077:
        raise PrivateStoreError("Private quarantine directory is unsafe")
    if not isinstance(referenced_keys, (set, frozenset)) or not all(
        type(key) is uuid.UUID for key in referenced_keys
    ):
        raise PrivateStoreError("Invalid reference snapshot")
    expected = {key.hex for key in referenced_keys}
    found = set()
    unsafe = []
    directory_fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY |
                           getattr(os, "O_NOFOLLOW", 0))
    try:
        # Do not produce a partial report if the file inventory is too large.
        names = os.listdir(directory_fd)
        if len(names) > MAX_INVENTORY_ENTRIES:
            raise PrivateStoreError("Quarantine inventory limit exceeded")
        if not stat.S_ISDIR(os.fstat(directory_fd).st_mode) or os.fstat(directory_fd).st_mode & 0o077:
            raise PrivateStoreError("Private quarantine permissions changed")
        for name in names:
            try:
                obj = uuid.UUID(hex=name)
                if obj.hex != name:
                    unsafe.append(name)
                    continue
                info = os.stat(name, dir_fd=directory_fd,
                               follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                    unsafe.append(name)
                    continue
                found.add(name)
            except (ValueError, OSError):
                unsafe.append(name)
    finally:
        os.close(directory_fd)
    return QuarantineAudit(
        objects_checked=len(found) + len(unsafe),
        referenced=len(found & expected),
        orphans=tuple(sorted(found - expected)),
        missing=tuple(sorted(expected - found)),
        unsafe=tuple(sorted(unsafe)),
    )
