"""Read-only, bounded metadata snapshot for an OFFLINE orphan report.

The snapshot is advisory: concurrent writers, backups and eventual consistency
mean this must never be used to authorize deletion or release of a file.
"""
import uuid
from dataclasses import dataclass
from django.db import transaction

from .attachment_model_router import attachment_model
from .attachment_orphan_audit import audit_private_quarantine

MAX_AUDIT_OBJECTS = 100_000


@dataclass(frozen=True)
class OrphanReconciliation:
    audit: object
    metadata_count: int
    advisory_only: bool = True
    deletion_authorized: bool = False


def audit_quarantine_against_database(*, root):
    """Produce a privacy-minimal report; no mutations, no filenames or PII."""
    with transaction.atomic():
        # The limit deliberately fails closed rather than providing an
        # incomplete set that might wrongly label valid objects as orphans.
        keys = list(attachment_model().objects.order_by().values_list(
            "storage_key", flat=True)[:MAX_AUDIT_OBJECTS + 1])
        if len(keys) > MAX_AUDIT_OBJECTS:
            raise ValueError("Attachment snapshot limit exceeded")
        if any(type(item) is not uuid.UUID for item in keys):
            raise ValueError("Invalid metadata identifier")
        result = audit_private_quarantine(root=root, referenced_keys=set(keys))
    return OrphanReconciliation(audit=result, metadata_count=len(keys))
