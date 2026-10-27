"""Attachment authorization scope and fail-closed download hold.

No trusted scanner/verifier exists yet. Even changing state to CLEAN by hand
must never make a byte stream accessible.
"""
from .models import RenewalAttachment
from .views import _visible_renewals


def accessible_attachment_queryset(membership):
    """Limit metadata to explicitly visible renewals in the workspace."""
    return RenewalAttachment.objects.filter(
        renewal_id__in=_visible_renewals(membership).values("pk"),
    )


def may_download_attachment(*, attachment, membership):
    """No download until independently verified scanning is implemented.

    Future implementation must compare a trusted scanner's signed verdict,
    the actual stored encrypted object's digest, workspace authorization and
    object lifecycle. Never enable based only on a mutable DB state.
    """
    return False
