"""Offline read-only verification of encrypted objects during schema transition.

Requires a write freeze and a dedicated quarantine key. This module never
returns decrypted contents, copies files, mutates metadata or permits download.
"""
import hashlib
import hmac
from dataclasses import dataclass

from reminders.attachment_private_store import PrivateStoreError
from .transition_reconciliation import inspect_reconciliation, Independent, Legacy

MAX_VERIFY_OBJECTS = 100_000


@dataclass(frozen=True)
class EncryptedObjectAudit:
    metadata_aligned: bool
    checked: int
    unreadable: int
    digest_mismatches: int
    size_mismatches: int
    release_authorized: bool = False


def verify_encrypted_objects_readonly(*, store):
    """Fail closed for any unmatched metadata; verify exact decrypted bytes.

    Advisory: metadata can change after the scan, and a file passing integrity
    does not imply it is free from malware. Never call from HTTP.
    """
    reconciliation = inspect_reconciliation()
    if (reconciliation.missing_in_independent or
        reconciliation.missing_in_legacy or
        reconciliation.conflicting_records or
        reconciliation.reused_storage_keys):
        return EncryptedObjectAudit(False, 0, 0, 0, 0)
    metadata = list(Independent.objects.order_by().values(
        "storage_key", "sha256", "byte_size")[:MAX_VERIFY_OBJECTS + 1])
    if len(metadata) > MAX_VERIFY_OBJECTS or len(metadata) != reconciliation.independent_count:
        raise ValueError("ENCRYPTED_OBJECT_AUDIT_LIMIT_OR_CONCURRENT_CHANGE")
    bad_read = bad_hash = bad_size = 0
    for item in metadata:
        try:
            payload = store.read_quarantine_for_scanner_only(item["storage_key"])
        except (PrivateStoreError, OSError, ValueError, TypeError):
            bad_read += 1
            continue
        bad_hash += int(not hmac.compare_digest(
            hashlib.sha256(payload).hexdigest(), item["sha256"]))
        bad_size += int(len(payload) != item["byte_size"])
    return EncryptedObjectAudit(
        True, len(metadata), bad_read, bad_hash, bad_size)
