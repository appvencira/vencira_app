"""Read-only preflight for attachment schema transition.

Never silently discard, copy or reclassify historical attachment records.
A transition from the legacy schema must be explicitly reconciled offline.
"""
from dataclasses import dataclass
from django.db import transaction

from reminders.models import RenewalAttachment as LegacyAttachment
from renewal_attachments.models import RenewalAttachment as IndependentAttachment


@dataclass(frozen=True)
class AttachmentTransitionReport:
    legacy_records: int
    independent_records: int
    safe_empty_transition: bool
    reason: str


def inspect_attachment_transition():
    """Use a consistent DB snapshot; no writes and no file access.

    A clean schema transition can only proceed if both tables are empty.
    Do not use this advisory report as a deployment authorization.
    """
    with transaction.atomic():
        legacy_count = LegacyAttachment.objects.count()
        independent_count = IndependentAttachment.objects.count()
    if legacy_count:
        reason = "LEGACY_RECORDS_REQUIRE_VERIFIED_RECONCILIATION"
    elif independent_count:
        reason = "INDEPENDENT_RECORDS_REQUIRE_VERIFIED_RECONCILIATION"
    else:
        reason = "EMPTY_SCHEMAS_ONLY"
    return AttachmentTransitionReport(
        legacy_records=legacy_count,
        independent_records=independent_count,
        safe_empty_transition=not (legacy_count or independent_count),
        reason=reason,
    )
