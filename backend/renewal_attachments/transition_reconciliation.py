"""Bounded read-only reconciliation of legacy and split attachment metadata.

Not a migration, object verifier, freeze, or release authorization.
"""
from dataclasses import dataclass
from django.db import transaction
from reminders.models import RenewalAttachment as Legacy
from .models import RenewalAttachment as Independent
from .transition_contract import FIELDS, compare_inventories

MAX_ROWS = 100_000


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
    """Counts only; READ COMMITTED atomic is not a universal snapshot/freeze.

    Requires both models present in an isolated historical-schema rehearsal.
    No object integrity is asserted and no automatic transition is allowed.
    """
    with transaction.atomic():
        old, new = _rows(Legacy), _rows(Independent)
    return ReconciliationReport(**compare_inventories(old, new))
