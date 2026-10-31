"""Offline attachment intake to private quarantine; never called by HTTP.

The caller must persist ownership metadata in a separate controlled transaction.
No result authorizes download or marks a file clean.
"""
import hashlib
import uuid
from dataclasses import dataclass

from .attachment_validation import validate_attachment_header
from .attachment_private_store import PrivateStoreError


@dataclass(frozen=True)
class StagedQuarantine:
    storage_key: uuid.UUID
    display_name: str
    content_type: str
    byte_size: int
    sha256: str
    state: str = "quarantined"
    download_allowed: bool = False


def stage_private_attachment(*, store, filename, content_type, content,
                             create_metadata, journal=None):
    """Validate and encrypt exact bytes; preserve evidence on uncertain commit.

    create_metadata(staged) must enforce workspace/renewal association, audit,
    permissions and database transaction itself. No public endpoint calls this.
    """
    if not isinstance(content, bytes):
        raise ValueError("Attachment must be immutable bytes")
    display_name, mime = validate_attachment_header(
        filename=filename, reported_type=content_type,
        header=content[:32], size=len(content))
    staged = StagedQuarantine(
        storage_key=uuid.uuid4(), display_name=display_name,
        content_type=mime, byte_size=len(content),
        sha256=hashlib.sha256(content).hexdigest())
    if journal is not None:
        journal.record_intent(staged.storage_key, staged.sha256)

    store.put_quarantine(staged.storage_key, content)
    # A metadata writer may commit its SQL transaction, then lose the
    # acknowledgement to this process (network error / crash / timeout).
    # We CANNOT prove rollback from an exception or a missing response.
    # Never discard the private ciphertext here: that could destroy an
    # attachment already referenced by committed PostgreSQL metadata.
    # Quarantine is non-public; recovery inventory must reconcile object,
    # durable intent (if present) and metadata in read-only mode.
    # This deliberately prefers an orphan requiring manual review over
    # irreversible destruction of an ambiguously committed attachment.
    record = create_metadata(staged)
    if record is None:
        raise PrivateStoreError("Metadata not confirmed")
    return record
