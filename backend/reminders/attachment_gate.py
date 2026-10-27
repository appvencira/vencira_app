"""Fail-closed attachment policy, not a public upload/download API.

Scanning is deliberately not implemented. Metadata state alone is insufficient
to grant a download. An independently verified scanner attestation is required.
"""
from dataclasses import dataclass

from .models import RenewalAttachment
from .views import _visible_renewals


@dataclass(frozen=True)
class ScanAttestation:
    object_key: str
    sha256: str
    verdict: str


def accessible_attachment_queryset(membership):
    """Only authorized renewals, including assignment restrictions."""
    return RenewalAttachment.objects.filter(
        renewal_id__in=_visible_renewals(membership).values("pk"),
    )


def may_download_attachment(*, attachment, membership, attestation=None):
    """Check all conditions; do not disclose existence to unauthorized users.

    This predicate does NOT substitute for verification of an attestation's
    origin, signature, age, or integrity. No caller should issue attestations
    until a trusted scanner and verification service exist.
    """
    if not accessible_attachment_queryset(membership).filter(pk=attachment.pk).exists():
        return False
    if attachment.state != RenewalAttachment.State.CLEAN:
        return False
    if not isinstance(attestation, ScanAttestation):
        return False
    return (
        attestation.object_key == attachment.storage_key.hex
        and attestation.sha256 == attachment.sha256
        and attestation.verdict == "clean"
    )
