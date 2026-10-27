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
                             create_metadata):
    """Validate and encrypt exact bytes; remove orphan on metadata failure.

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
    store.put_quarantine(staged.storage_key, content)
    try:
        record = create_metadata(staged)
        if record is None:
            raise PrivateStoreError("Metadata not confirmed")
        return record
    except BaseException:
        # Failure must never leave an untracked readable file behind.
        # Storage implementation must provide a private object cleanup method.
        store.discard_quarantine(staged.storage_key)
        raise
