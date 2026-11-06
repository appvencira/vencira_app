"""Manual follow-up lifecycle; stores civil dates but never dispatches notifications."""
from datetime import date

from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Renewal, RenewalAuditEvent, RenewalFollowUp
from .views import _membership, _visible_renewals


def _present(row):
    if row is None:
        return None
    return {
        "id": str(row.id),
        "scheduled_for": row.scheduled_for.isoformat(),
        "state": row.state,
    }


def _log(*, renewal, actor, action, previous=None, current=None):
    # Append-only from application code; no personal details in metadata.
    RenewalAuditEvent.objects.create(
        workspace_id=renewal.workspace_id, renewal=renewal, actor=actor,
        action=RenewalAuditEvent.Action.UPDATED,
        changed_fields=["manual_follow_up"],
        metadata={"manual_follow_up": {
            "action": action,
            "before": previous.isoformat() if previous is not None else None,
            "after": current.isoformat() if current is not None else None,
        }},
    )


def _date(raw):
    if not isinstance(raw, str) or len(raw) != 10:
        return None
    try:
        value = date.fromisoformat(raw)
    except (TypeError, ValueError):
        return None
    if value.isoformat() != raw or not (2000 <= value.year <= 2100):
        return None
    return value


@api_view(["GET", "POST", "PATCH"])
@permission_classes([IsAuthenticated])
def manual_follow_up(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    visible = _visible_renewals(membership)
    if request.method == "GET":
        renewal = get_object_or_404(visible, pk=renewal_id)
        active = RenewalFollowUp.objects.filter(
            renewal=renewal, state=RenewalFollowUp.State.PLANNED,
        ).first()
        response = Response({"active": _present(active)})
        response["Cache-Control"] = "no-store"
        return response

    with transaction.atomic():
        # Lock the renewal even when no follow-up exists to serialize
        # concurrent schedule/reschedule/cancel requests in PostgreSQL.
        renewal = get_object_or_404(visible.select_for_update(), pk=renewal_id)
        if renewal.status == Renewal.Status.CLOSED:
            return Response(
                {"detail": "No se puede programar en una anotación cerrada."},
                status=status.HTTP_409_CONFLICT,
            )
        active = RenewalFollowUp.objects.select_for_update().filter(
            renewal=renewal, state=RenewalFollowUp.State.PLANNED,
        ).first()

        if request.method == "POST":
            if (not isinstance(request.data, dict) or
                    set(request.data) != {"scheduled_for"}):
                return Response({"scheduled_for": "Solo se permite una fecha."},
                                status=status.HTTP_400_BAD_REQUEST)
            target = _date(request.data["scheduled_for"])
            if target is None:
                return Response({"scheduled_for": "Fecha civil inválida."},
                                status=status.HTTP_400_BAD_REQUEST)
            if active is not None and active.scheduled_for == target:
                return Response({"active": _present(active)})
            previous = active.scheduled_for if active else None
            if active is not None:
                active.state = RenewalFollowUp.State.CANCELLED
                active.closed_by = request.user
                active.save(update_fields=["state", "closed_by", "updated_at"])
            created = RenewalFollowUp.objects.create(
                renewal=renewal, scheduled_for=target,
                created_by=request.user,
            )
            _log(renewal=renewal, actor=request.user,
                 action="rescheduled" if previous else "scheduled",
                 previous=previous, current=target)
            response = Response({"active": _present(created)},
                                status=status.HTTP_201_CREATED)
        else:
            if (not isinstance(request.data, dict) or
                    set(request.data) != {"id", "action"} or
                    request.data["action"] not in ("complete", "cancel")):
                return Response({"action": "Acción no válida."},
                                status=status.HTTP_400_BAD_REQUEST)
            if active is None or str(active.id) != request.data["id"]:
                return Response(
                    {"detail": "El seguimiento ya no está activo."},
                    status=status.HTTP_409_CONFLICT,
                )
            action = request.data["action"]
            active.state = (RenewalFollowUp.State.COMPLETED
                            if action == "complete"
                            else RenewalFollowUp.State.CANCELLED)
            active.closed_by = request.user
            active.save(update_fields=["state", "closed_by", "updated_at"])
            _log(renewal=renewal, actor=request.user,
                 action="completed" if action == "complete" else "cancelled",
                 previous=active.scheduled_for)
            response = Response({"active": None})
    response["Cache-Control"] = "no-store"
    return response
