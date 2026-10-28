"""Test-only rejection of quarantined attachments, without public deletion.

Mark rejected transactionally before attempting private object disposal. Any
storage failure leaves a rejected, non-downloadable record for reconciliation.
Never delete audit metadata or signed evidence.
"""
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction
from django.http import Http404
from reminders.models import WorkspaceMember
from reminders.attachment_private_store import PrivateStoreError
from .models import RenewalAttachment


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
        key = item.storage_key
        item.state = RenewalAttachment.State.REJECTED
        item.save(update_fields=["state"])
    try:
        store.discard_quarantine(key)
    except (PrivateStoreError, OSError, ValueError):
        return RejectionOutcome(item.pk, item.state, False, True)
    return RejectionOutcome(item.pk, item.state, True, False)
