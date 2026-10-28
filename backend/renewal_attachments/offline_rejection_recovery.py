"""Test-only recovery for rejected attachment objects left after failed cleanup.

No reactivation, file reads, HTTP surface or metadata deletion. A missing object
is handled as already discarded only if the underlying private store reports
ENOENT; other errors remain pending for operator reconciliation.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection, transaction
from django.utils import timezone
from django.http import Http404
from reminders.models import WorkspaceMember
from reminders.attachment_private_store import PrivateStoreError
from .models import RenewalAttachment, AttachmentDiscardJob
from .offline_rejection import RejectionOutcome


def retry_rejected_discard_offline(*, member, attachment_id, store):
    if (settings.VENCIRA_ENV != "test" or not
            getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)):
        raise PermissionDenied("Recovery restricted to rehearsal")
    if member is None or not member.pk:
        raise PermissionDenied("Membership required")
    if connection.in_atomic_block:
        raise PermissionDenied("Storage cleanup prohibited inside a transaction")
    active = WorkspaceMember.objects.get(
        pk=member.pk, workspace_id=member.workspace_id, user_id=member.user_id)
    if active.role != WorkspaceMember.Role.OWNER:
        raise PermissionDenied("Owner role required")
    item = RenewalAttachment.objects.filter(
        pk=attachment_id, renewal__workspace_id=active.workspace_id).first()
    if item is None:
        raise Http404("Attachment not found")
    if item.state != RenewalAttachment.State.REJECTED:
        raise PermissionDenied("Only rejected objects may be discarded")
    with transaction.atomic():
        job = AttachmentDiscardJob.objects.select_for_update().get(
            attachment=item)
        if job.status == AttachmentDiscardJob.Status.COMPLETED:
            return RejectionOutcome(item.pk, item.state, True, False)
        job.attempts += 1
        job.save(update_fields=["attempts"])
    try:
        store.discard_quarantine(item.storage_key)
    except (PrivateStoreError, OSError, ValueError):
        AttachmentDiscardJob.objects.filter(pk=job.pk, status="pending").update(
            last_error="STORAGE_DISCARD_FAILED")
        return RejectionOutcome(item.pk, item.state, False, True)
    AttachmentDiscardJob.objects.filter(pk=job.pk, status="pending").update(
        status="completed", last_error="", completed_at=timezone.now())
    return RejectionOutcome(item.pk, item.state, True, False)
