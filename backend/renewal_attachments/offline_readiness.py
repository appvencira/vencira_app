"""Offline security readiness assessment; no bytes or release permission.

This assesses prerequisites, not a download authorization. It MUST NOT be
used as the final release gate and is test-only pending scanner isolation.
"""
import hashlib
import hmac
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied
from reminders.attachment_private_store import PrivateStoreError
from reminders.attachment_scan_contract import verify_scan_verdict
from reminders.models import WorkspaceMember
from .models import RenewalAttachment, AttachmentScanEvidence


@dataclass(frozen=True)
class ReadinessAssessment:
    metadata_authorized: bool
    signed_evidence_valid: bool
    encrypted_object_integrity: bool
    ready_for_security_review: bool
    release_allowed: bool = False


def assess_attachment_readiness(*, member, attachment_id, store,
                                verification_key, now=None):
    if settings.VENCIRA_ENV != "test" or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False):
        raise PermissionDenied("Readiness assessment restricted to rehearsal")
    # Authenticated membership is reloaded; caller-supplied workspace alone
    # must never authorize access to another organization's object.
    member = WorkspaceMember.objects.get(
        pk=member.pk, user_id=member.user_id, workspace_id=member.workspace_id)
    queryset = RenewalAttachment.objects.filter(
        pk=attachment_id, renewal__workspace_id=member.workspace_id)
    if member.role != WorkspaceMember.Role.OWNER:
        queryset = queryset.filter(renewal__assigned_to_id=member.user_id)
    attachment = queryset.first()
    if attachment is None:
        return ReadinessAssessment(False, False, False, False)
    if attachment.state != RenewalAttachment.State.QUARANTINED:
        return ReadinessAssessment(True, False, False, False)
    evidence = list(AttachmentScanEvidence.objects.filter(
        attachment=attachment).order_by().values("payload", "signature")[:2])
    signed = len(evidence) == 1 and verify_scan_verdict(
        payload=evidence[0]["payload"], signature=evidence[0]["signature"],
        verification_key=verification_key, attachment=attachment, now=now)
    integrity = False
    if signed:
        try:
            data = store.read_quarantine_for_scanner_only(attachment.storage_key)
            integrity = (len(data) == attachment.byte_size and
                hmac.compare_digest(hashlib.sha256(data).hexdigest(),
                                    attachment.sha256))
        except (PrivateStoreError, ValueError, OSError, TypeError):
            integrity = False
    return ReadinessAssessment(True, bool(signed), integrity,
                               bool(signed and integrity))
