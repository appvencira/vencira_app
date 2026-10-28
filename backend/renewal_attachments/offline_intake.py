"""Isolated offline intake: authorization, DB metadata and encrypted quarantine.

Not exposed through HTTP. Call only with synthetic content in test mode.
A trusted scanner and file-release lifecycle are not implemented here.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction
from django.shortcuts import get_object_or_404

from reminders.attachment_model_router import attachment_model
from reminders.attachment_quarantine_intake import stage_private_attachment
from reminders.models import Renewal, WorkspaceMember


def stage_authorized_attachment(*, member, renewal_id, store,
                                filename, content_type, content):
    if (settings.VENCIRA_ENV != "test" or
            not getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)):
        raise PermissionDenied("Intake restricted to isolated rehearsal")
    if member is None or not member.pk:
        raise PermissionDenied("Membership required")
    valid_member = WorkspaceMember.objects.select_related("workspace").get(
        pk=member.pk, user_id=member.user_id, workspace_id=member.workspace_id)
    visible = Renewal.objects.filter(workspace_id=valid_member.workspace_id)
    if valid_member.role != WorkspaceMember.Role.OWNER:
        visible = visible.filter(assigned_to_id=valid_member.user_id)
    renewal = get_object_or_404(visible, pk=renewal_id)

    def create_metadata(staged):
        with transaction.atomic():
            return attachment_model().objects.create(
                renewal=renewal, uploaded_by=valid_member.user,
                storage_key=staged.storage_key, display_name=staged.display_name,
                content_type=staged.content_type, byte_size=staged.byte_size,
                sha256=staged.sha256, state="quarantined")

    return stage_private_attachment(
        store=store, filename=filename, content_type=content_type,
        content=content, create_metadata=create_metadata)
