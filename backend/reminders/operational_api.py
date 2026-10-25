"""Read-only access to planned reminders, without sending messages."""
import uuid
from datetime import date
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import OperationalReminder
from .operational_transitions import ReminderConflict, transition_reminder
from .views import _membership, _visible_renewals

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def operational_reminders(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(_visible_renewals(membership), pk=renewal_id)
    if request.query_params:
        return Response({"detail": "Query parameters not supported."}, status=400)
    rows = OperationalReminder.objects.filter(renewal=renewal).order_by("scheduled_for", "id")[:200]
    response = Response({"results": [
        {"id": str(r.pk), "kind": r.kind, "scheduled_for": r.scheduled_for.isoformat(),
         "days_before": r.days_before, "reason": r.reason, "state": r.state,
         "control_question": r.control_question, "generation": r.generation,
         "delivery_status": "not_implemented"} for r in rows
    ]})
    response["Cache-Control"] = "no-store"
    return response


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def operational_reminder_action(request, workspace_id, renewal_id, reminder_id):
    """Authenticated CAS command; internal status only, never a delivery."""
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(_visible_renewals(membership), pk=renewal_id)
    get_object_or_404(OperationalReminder, pk=reminder_id, renewal=renewal)
    if request.query_params:
        return Response({"detail": "Query parameters not supported."}, status=400)
    data = request.data
    if type(data) is not dict or set(data) != {
        "action", "expected_state", "expected_day", "idempotency_key", "days_later"
    }:
        return Response({"detail": "Invalid action payload."}, status=400)
    try:
        if type(data["expected_day"]) is not str:
            raise ValueError()
        day = date.fromisoformat(data["expected_day"])
        if day.isoformat() != data["expected_day"]:
            raise ValueError()
        if type(data["idempotency_key"]) is not str:
            raise ValueError()
        key = uuid.UUID(data["idempotency_key"])
        if str(key) != data["idempotency_key"]:
            raise ValueError()
        reminder = transition_reminder(
            renewal_id=renewal.pk, reminder_id=reminder_id,
            action=data["action"], expected_state=data["expected_state"],
            expected_day=day, idempotency_key=key,
            days_later=data["days_later"], actor=request.user,
        )
    except (ValueError, TypeError, OverflowError) as exc:
        # CAS conflicts carry a separate HTTP status for client reload.
        code = 409 if isinstance(exc, ReminderConflict) else 400
        return Response({"detail": str(exc) or "Invalid date or key."}, status=code)
    response = Response({
        "id": str(reminder.pk), "state": reminder.state,
        "scheduled_for": reminder.scheduled_for.isoformat(),
        "delivery_status": "not_implemented",
    })
    response["Cache-Control"] = "no-store"
    return response
