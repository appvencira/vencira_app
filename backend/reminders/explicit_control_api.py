"""C2 explicit internal control notice, never email/push or evidence of delivery."""
import uuid
from datetime import date
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .c2_control_policy import evaluate_c2_control_policy
from .default_reminders import DEFAULT_DAYS_BEFORE
from .models import Renewal, RenewalReminderDraft, OperationalReminder
from .operational_reconcile import _event
from .views import _membership, _visible_renewals


def _reply(reminder, code):
    response = Response({
        "id": str(reminder.pk), "scheduled_for": reminder.scheduled_for.isoformat(),
        "control_question": True, "state": reminder.state,
        "delivery_status": "not_implemented",
    }, status=code)
    response["Cache-Control"] = "no-store"
    return response


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def explicit_control_notice(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    if request.query_params or type(request.data) is not dict or set(request.data) != {
        "confirmed", "scheduled_for", "idempotency_key",
    }:
        return Response({"detail": "Solicitud inválida."}, status=400)
    data = request.data
    if data["confirmed"] is not True:
        return Response({"detail": "Confirmación expresa requerida."}, status=400)
    try:
        if type(data["scheduled_for"]) is not str or type(data["idempotency_key"]) is not str:
            raise ValueError()
        scheduled = date.fromisoformat(data["scheduled_for"])
        key = uuid.UUID(data["idempotency_key"])
        if scheduled.isoformat() != data["scheduled_for"] or str(key) != data["idempotency_key"]:
            raise ValueError()
    except (ValueError, TypeError, OverflowError):
        return Response({"detail": "Fecha o UUID inválidos."}, status=400)

    with transaction.atomic():
        renewal = get_object_or_404(
            _visible_renewals(membership).select_for_update(), pk=renewal_id)
        source_key = f"explicit-control:{key}"
        prior = OperationalReminder.objects.filter(
            renewal=renewal, source_key=source_key, generation=1).first()
        if prior is not None:
            if prior.original_scheduled_for != scheduled or not prior.control_question:
                return Response({"detail": "Clave usada con otra fecha."}, status=409)
            return _reply(prior, 200)
        if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
            return Response({"detail": "Anotación cerrada."}, status=409)
        draft = RenewalReminderDraft.objects.filter(renewal=renewal).first()
        offsets = list(draft.days_before) if draft else list(DEFAULT_DAYS_BEFORE)
        today = timezone.localdate()
        policy = evaluate_c2_control_policy(
            renewal.expires_on, offsets, as_of=today,
            is_life=renewal.modality == "vida")
        if not policy.offer_explicit_control or policy.latest_explicit_control_day is None:
            return Response({"detail": "Control expreso no permitido: revisión manual."}, status=409)
        if not today <= scheduled <= policy.latest_explicit_control_day:
            return Response({"detail": "Fecha fuera de margen civil."}, status=400)
        existing = OperationalReminder.objects.filter(
            renewal=renewal, control_question=True,
            state__in=("planned", "pending", "snoozed"),
            scheduled_for=scheduled,
        ).exists()
        if existing:
            return Response({"detail": "Ya existe un control para esta fecha."}, status=409)
        item = OperationalReminder.objects.create(
            renewal=renewal, kind=OperationalReminder.Kind.CONTROL_REPEAT,
            source_key=source_key, generation=1, scheduled_for=scheduled,
            original_scheduled_for=scheduled, control_question=True,
            reason="Comprobar comunicación de no renovación",
        )
        _event(item, "planned", "", request.user)
        return _reply(item, 201)
