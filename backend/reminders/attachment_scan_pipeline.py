"""Quarantine-only orchestration: decrypt, hash, preinspect and invoke scanner.

Never changes DB state, signs verdicts, or enables downloads. A successful
scanner result does not equal an authorized release.
"""
import hashlib
import hmac
from dataclasses import dataclass

from .attachment_content_inspection import preinspect
from .attachment_clamav_adapter import scan_with_clamd
from .attachment_private_store import PrivateStoreError


@dataclass(frozen=True)
class QuarantineScanResult:
    verdict: str
    reason: str
    release_allowed: bool = False


def scan_encrypted_quarantine(*, store, attachment, socket_path, scanner=scan_with_clamd):
    """Only scans exact bytes matching the metadata; always fail closed."""
    try:
        content = store.read_quarantine_for_scanner_only(attachment.storage_key)
        digest = hashlib.sha256(content).hexdigest()
        if not hmac.compare_digest(digest, attachment.sha256):
            return QuarantineScanResult("error", "SHA256_MISMATCH")
        if len(content) != attachment.byte_size:
            return QuarantineScanResult("error", "SIZE_MISMATCH")
        result = preinspect(
            filename=attachment.display_name, reported_type=attachment.content_type,
            data=content,
        )
        if not result.structurally_valid:
            return QuarantineScanResult("error", "STRUCTURE_REJECTED")
        scanned = scanner(payload=content, unix_socket=socket_path)
        if scanned.verdict not in ("clean", "infected"):
            return QuarantineScanResult("error", "SCANNER_ERROR")
        return QuarantineScanResult(scanned.verdict, "SCANNER_UNATTESTED")
    except (PrivateStoreError, ValueError, TypeError, AttributeError, OSError):
        return QuarantineScanResult("error", "QUARANTINE_UNAVAILABLE")
