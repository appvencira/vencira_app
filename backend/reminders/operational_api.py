"""Read-only access to planned reminders, without sending messages."""
from django.shortcuts import get_object_or_404
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import OperationalReminder
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
