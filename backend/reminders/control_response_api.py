"""O9b-2: explicit MANUAL control answer. No delivery or scheduled jobs."""
import uuid

from django.db import transaction
from django.db.models import Max
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .control_responses import validate_control_response
from .models import Renewal, RenewalControlResponse
from .views import _membership, _visible_renewals


def _reply(body, code=status.HTTP_200_OK):
    response = Response(body, status=code)
    response["Cache-Control"] = "no-store"
    return response


def _serialize(obj):
    return {
        "id": str(obj.pk),
        "answer": obj.answer,
        "yes_option": obj.yes_option or None,
        "repeat_on": obj.repeat_on.isoformat() if obj.repeat_on else None,
        "cutoff_on": obj.cutoff_on.isoformat(),
        "revision": obj.revision,
        "answered_at": obj.answered_at.isoformat(),
        "actor_id": obj.actor_id,
        "origin": "manual",
        "notice_scheduled": False,
        "notice_delivered": False,
    }


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def control_responses(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    scoped = _visible_renewals(membership)
    if request.query_params:
        return _reply({"detail": "Parámetros no permitidos."}, 400)
    if request.method == "GET":
        renewal = get_object_or_404(scoped, pk=renewal_id)
        rows = RenewalControlResponse.objects.filter(
            renewal=renewal,
        ).order_by("-revision")[:100]
        return _reply({"results": [_serialize(row) for row in rows]})

    if request.content_type.split(";", 1)[0].lower().strip() != "application/json":
        return _reply({"detail": "Se requiere JSON."}, 400)
    payload = request.data
    if type(payload) is not dict or set(payload) != {
        "origin", "revision", "idempotency_key", "answer", "yes_option", "days_later",
    }:
        return _reply({"detail": "Contrato de respuesta inválido."}, 400)
    if payload["origin"] != "manual":
        return _reply({"detail": "Solo anotación manual, sin evidencia de entrega."}, 400)
    revision = payload["revision"]
    if type(revision) is not int or revision < 0 or revision > 2147483646:
        return _reply({"detail": "Revisión inválida."}, 400)
    try:
        key = uuid.UUID(payload["idempotency_key"])
        if str(key) != payload["idempotency_key"]:
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        return _reply({"detail": "Clave idempotente inválida."}, 400)
    with transaction.atomic():
        renewal = get_object_or_404(scoped.select_for_update(), pk=renewal_id)
        if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
            return _reply({"detail": "Anotación cerrada o archivada."}, 409)
        old = RenewalControlResponse.objects.filter(
            renewal=renewal, idempotency_key=key,
        ).first()
        if old is not None:
            if (old.answer != payload["answer"]
                    or (old.yes_option or None) != payload["yes_option"]
                    or old.repeat_on is not None and payload["answer"] == "yes"
                    or old.revision != revision + 1):
                return _reply({"detail": "Clave reutilizada con otros datos."}, 409)
            return _reply(_serialize(old))
        current_revision = RenewalControlResponse.objects.filter(
            renewal=renewal,
        ).aggregate(value=Max("revision"))["value"] or 0
        if revision != current_revision:
            return _reply({
                "detail": "Revisión obsoleta.", "current_revision": current_revision,
            }, 409)
        today = timezone.localdate()
        try:
            plan = validate_control_response(
                renewal.expires_on, as_of=today,
                answer=payload["answer"],
                yes_option=payload["yes_option"],
                days_later=payload["days_later"],
                requires_manual_review=(renewal.modality == "vida"),
            )
        except (TypeError, ValueError) as exc:
            return _reply({"detail": str(exc)}, 400)
        row = RenewalControlResponse.objects.create(
            renewal=renewal, actor=request.user, answer=plan.answer,
            yes_option=plan.yes_option or "", repeat_on=plan.repeat_on,
            cutoff_on=plan.cutoff_on, revision=revision + 1,
            idempotency_key=key,
        )
        return _reply(_serialize(row), 201)
