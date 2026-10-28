"""Bounded advisory comparison of old and independent attachment metadata.

No byte access, copying, deletion, automatic authorization or PII in results.
Intended only for isolated migration rehearsal after both schemas exist.
"""
from dataclasses import dataclass
from django.db import transaction
from reminders.models import RenewalAttachment as Legacy
from .models import RenewalAttachment as Independent

MAX_ROWS = 100_000
FIELDS = ("id", "renewal_id", "uploaded_by_id", "display_name",
          "content_type", "byte_size", "sha256", "storage_key", "state")


@dataclass(frozen=True)
class ReconciliationReport:
    legacy_count: int
    independent_count: int
    missing_in_independent: int
    missing_in_legacy: int
    conflicting_records: int
    reused_storage_keys: int
    release_authorized: bool = False


def _rows(model):
    rows = list(model.objects.order_by().values(*FIELDS)[:MAX_ROWS + 1])
    if len(rows) > MAX_ROWS:
        raise ValueError("ATTACHMENT_RECONCILIATION_LIMIT")
    return rows


def inspect_reconciliation():
    """Return counts only. Not race-safe without a database write freeze.

    Identical IDs are not sufficient: every metadata field must agree.
    A reused storage key across different IDs is a blocker. Reporting does
    not assert existence, digest, or integrity of encrypted file bytes.
    """
    with transaction.atomic():
        old, new = _rows(Legacy), _rows(Independent)
    old_by_id = {r["id"]: r for r in old}
    new_by_id = {r["id"]: r for r in new}
    if len(old_by_id) != len(old) or len(new_by_id) != len(new):
        raise ValueError("ATTACHMENT_DUPLICATE_IDS")
    shared = old_by_id.keys() & new_by_id.keys()
    conflicts = sum(old_by_id[k] != new_by_id[k] for k in shared)
    old_keys = {r["storage_key"]: r["id"] for r in old}
    new_keys = {r["storage_key"]: r["id"] for r in new}
    reused = sum(old_keys[k] != new_keys[k]
                 for k in old_keys.keys() & new_keys.keys())
    return ReconciliationReport(
        legacy_count=len(old), independent_count=len(new),
        missing_in_independent=len(old_by_id.keys() - new_by_id.keys()),
        missing_in_legacy=len(new_by_id.keys() - old_by_id.keys()),
        conflicting_records=conflicts,
        reused_storage_keys=reused,
    )
