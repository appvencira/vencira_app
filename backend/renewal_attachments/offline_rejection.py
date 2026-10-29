"""Test-only rejection of quarantined attachments, without public deletion.

Mark rejected transactionally before attempting private object disposal. Any
storage failure leaves a rejected, non-downloadable record for reconciliation.
Never delete audit metadata or signed evidence.
"""
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction, connection
from django.http import Http404
from reminders.models import WorkspaceMember
from .offline_write_barrier_b06b import advisory_barrier
from .models import RenewalAttachment, AttachmentDiscardJob


@dataclass(frozen=True)
class RejectionOutcome:
    attachment_id: object
    state: str
    private_object_discarded: bool
    needs_storage_reconciliation: bool
    release_allowed: bool = False


def reject_attachment_offline(*, member, attachment_id, store):
    if settings.VENCIRA_ENV != "test" or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False):
        raise PermissionDenied("Offline rejection restricted to rehearsal")
    if member is None or not member.pk:
        raise PermissionDenied("Membership required")
    # A caller transaction could roll back after bytes were destroyed.
    if connection.in_atomic_block:
        raise PermissionDenied("Rejection requires an outermost committed transaction")
    with advisory_barrier(capture=False):
        with transaction.atomic():
            active = WorkspaceMember.objects.get(
                pk=member.pk, workspace_id=member.workspace_id,
                user_id=member.user_id)
            # Destructive action requires an owner rather than assignment alone.
            if active.role != WorkspaceMember.Role.OWNER:
                raise PermissionDenied("Owner role required for rejection")
            item = RenewalAttachment.objects.select_for_update().filter(
                pk=attachment_id, renewal__workspace_id=active.workspace_id).first()
            if item is None:
                raise Http404("Attachment not found")
            if item.state != RenewalAttachment.State.QUARANTINED:
                raise PermissionDenied("Only quarantined attachments can be rejected")
            item.state = RenewalAttachment.State.REJECTED
            item.save(update_fields=["state"])
            AttachmentDiscardJob.objects.create(attachment=item)
        from .offline_rejection_recovery import retry_rejected_discard_offline
        return retry_rejected_discard_offline(
            member=member, attachment_id=item.pk, store=store)
