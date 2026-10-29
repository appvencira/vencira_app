"""Test-only persistence of signed clean scan evidence.

The signer must be isolated in a real deployment. This service never marks
a document CLEAN, enables downloads, or exposes signatures via HTTP.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction

from reminders.attachment_scan_contract import verify_scan_verdict
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_write_barrier_b06b import advisory_barrier


def persist_scan_evidence_offline(*, attachment_id, payload, signature,
                                  verification_key, now=None, expected_fingerprint=None):
    if (settings.VENCIRA_ENV != "test" or
            not getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)):
        raise PermissionDenied("Signed evidence persistence is test only")
    with advisory_barrier(capture=False):
        with transaction.atomic():
            attachment = RenewalAttachment.objects.select_for_update().get(
                pk=attachment_id)
            if expected_fingerprint is not None:
                fields = ("storage_key", "sha256", "byte_size", "state",
                          "display_name", "content_type")
                if tuple(getattr(attachment, field) for field in fields) != tuple(expected_fingerprint):
                    raise PermissionDenied("Attachment metadata changed during scan")
            if attachment.state != RenewalAttachment.State.QUARANTINED:
                raise PermissionDenied("Attachment is no longer quarantined")
            if AttachmentScanEvidence.objects.filter(attachment=attachment).exists():
                raise PermissionDenied("Scan evidence already recorded")
            if not verify_scan_verdict(
                    payload=payload, signature=signature,
                    verification_key=verification_key, attachment=attachment,
                    now=now):
                raise PermissionDenied("Unverified scanner evidence")
            return AttachmentScanEvidence.objects.create(
                attachment=attachment, payload=payload, signature=signature)
