"""Explicit scheduling of a saved reminder draft; does not dispatch messages.

This action is bound to an authenticated account and a visible annotation.
No background task, notifications or delivery evidence is created.
"""
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Renewal, RenewalReminderDraft
from .operational_reconcile import reconcile_expiry_reminders
from .views import _membership, _visible_renewals


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def activate_reminder_draft(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    scoped = _visible_renewals(membership)
    if request.query_params or request.content_type.split(";", 1)[0].strip().lower() != "application/json":
        return Response({"detail": "Invalid request."}, status=400)
    body = request.data
    if type(body) is not dict or set(body) != {"expected_revision"}:
        return Response({"detail": "Invalid payload."}, status=400)
    expected = body["expected_revision"]
    if type(expected) is not int or expected < 1:
        return Response({"detail": "Invalid revision."}, status=400)
    with transaction.atomic():
        renewal = get_object_or_404(scoped.select_for_update(), pk=renewal_id)
        if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
            return Response({"detail": "Annotation closed."}, status=409)
        draft = get_object_or_404(RenewalReminderDraft, renewal=renewal)
        if expected != draft.revision:
            return Response({"detail": "Revision conflict.",
                             "current_revision": draft.revision}, status=409)
        try:
            occurrences = reconcile_expiry_reminders(
                renewal.pk, as_of=timezone.localdate(),
                days_before=draft.days_before, actor=request.user)
        except (ValueError, OverflowError) as exc:
            return Response({"detail": str(exc)}, status=409)
        response = Response({
            "state": "internally_planned",
            "draft_revision": draft.revision,
            "planned_count": sum(item.state == "planned" for item in occurrences),
            "notification_delivery": "not_implemented",
        })
        response["Cache-Control"] = "no-store"
        return response
