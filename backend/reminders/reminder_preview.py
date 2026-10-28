"""O8b: endpoint de VISTA PREVIA de avisos sin escrituras ni envíos."""
import re

from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .reminder_planning import preview_reminder_plan
from .models import Renewal
from .views import _membership, _visible_renewals


def _days(query):
    if not query:
        return (60, 45, 35)
    if set(query.keys()) != {"days"} or len(query.getlist("days")) != 1:
        return None
    raw = query.get("days", "")
    if not re.fullmatch(r"(?:0|[1-9][0-9]{0,2})(?:,(?:0|[1-9][0-9]{0,2})){0,11}", raw):
        return None
    value = tuple(int(part) for part in raw.split(","))
    if any(n > 365 for n in value) or len(value) != len(set(value)):
        return None
    return value


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def renewal_reminder_preview(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(_visible_renewals(membership), pk=renewal_id)
    if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
        response = Response({"detail": "No se preparan avisos para anotaciones archivadas."},
                            status=status.HTTP_409_CONFLICT)
        response["Cache-Control"] = "no-store"
        return response
    days = _days(request.query_params)
    if days is None:
        response = Response({"days": "Anticipaciones no válidas."},
                            status=status.HTTP_400_BAD_REQUEST)
        response["Cache-Control"] = "no-store"
        return response
    # El cálculo es de fechas civiles, no de fecha de entrega de push/email.
    plan = preview_reminder_plan(renewal.expires_on, days, as_of=timezone.localdate())
    response = Response({
        "expires_on": plan.expires_on.isoformat(),
        "reference_day": plan.reference_day.isoformat(),
        "informational_cutoff_on": plan.cutoff_on.isoformat(),
        "no_pre_cutoff_notice": plan.no_pre_cutoff_notice,
        "late_control_needs_decision": plan.late_control_needs_decision,
        "cutoff_already_elapsed": plan.cutoff_already_elapsed,
        "reminders": [{
            "days_before": item.days_before,
            "scheduled_for": item.scheduled_for.isoformat(),
            "before_cutoff": item.before_cutoff,
            "control_question": item.control_question,
            "already_elapsed": item.already_elapsed,
        } for item in plan.reminders],
        "life_rule_requires_review": renewal.modality == "vida",
        "preview_only": True,
        "delivered": False,
    })
    response["Cache-Control"] = "no-store"
    return response
