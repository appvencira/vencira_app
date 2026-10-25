"""O8c: configuración privada de avisos POR ANOTACIÓN, únicamente draft.

GET es lectura; PUT almacena preferencias pero NO crea candidatos, envíos,
trabajos, políticas habilitadas ni respuestas a avisos. Un conflicto de
revisión falla cerrado en lugar de sobrescribir cambios ajenos.
"""
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .default_reminders import DEFAULT_DAYS_BEFORE
from .models import Renewal, RenewalReminderDraft
from .reminder_planning import preview_reminder_plan
from .views import _membership, _visible_renewals


def _response(body, code=status.HTTP_200_OK):
    result = Response(body, status=code)
    result["Cache-Control"] = "no-store"
    return result


def _contract(renewal, draft):
    defaults = draft is None
    days = list(DEFAULT_DAYS_BEFORE) if defaults else list(draft.days_before)
    preview = preview_reminder_plan(
        renewal.expires_on, days, as_of=timezone.localdate(),
    )
    return {
        "state": "draft",
        "is_persisted": not defaults,
        "revision": 0 if defaults else draft.revision,
        "days_before": days,
        "reasons_by_day": {} if defaults else draft.reasons_by_day,
        "reference_day": preview.reference_day.isoformat(),
        "informational_cutoff_on": preview.cutoff_on.isoformat(),
        "no_pre_cutoff_notice": preview.no_pre_cutoff_notice,
        "late_control_needs_decision": preview.late_control_needs_decision,
        "cutoff_already_elapsed": preview.cutoff_already_elapsed,
        "life_rule_requires_review": renewal.modality == "vida",
        "scheduling_enabled": False,
        "delivered": False,
    }


def _clean_payload(request):
    if request.content_type.split(";", 1)[0].strip().lower() != "application/json":
        return None
    payload = request.data
    if type(payload) is not dict or not {"state", "revision", "days_before"} <= set(payload) or set(payload) - {"state", "revision", "days_before", "reasons_by_day"}:
        return None
    if payload["state"] != "draft":
        return None
    revision = payload["revision"]
    if type(revision) is not int or revision < 0 or revision > 2147483646:
        return None
    days = payload["days_before"]
    if type(days) is not list or not 1 <= len(days) <= 12:
        return None
    if (any(type(x) is not int or not 0 <= x <= 365 for x in days)
            or len(set(days)) != len(days)):
        return None
    reasons = payload.get("reasons_by_day", None)
    if reasons is not None:
        if type(reasons) is not dict or len(reasons) > 12:
            return None
        if any(type(k) is not str or k not in {str(d) for d in days}
               or type(v) is not str or not 1 <= len(v.strip()) <= 160
               for k, v in reasons.items()):
            return None
        reasons = {k: v.strip() for k, v in reasons.items()}
    return revision, sorted(days, reverse=True), reasons


@api_view(["GET", "PUT"])
@permission_classes([IsAuthenticated])
def reminder_draft(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    scoped = _visible_renewals(membership)
    if request.method == "GET":
        renewal = get_object_or_404(scoped, pk=renewal_id)
        if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
            return _response({"detail": "Anotación cerrada o archivada."},
                             status.HTTP_409_CONFLICT)
        if request.query_params:
            return _response({"detail": "Parámetros no admitidos."},
                             status.HTTP_400_BAD_REQUEST)
        current = RenewalReminderDraft.objects.filter(renewal_id=renewal.pk).first()
        return _response(_contract(renewal, current))

    parsed = _clean_payload(request)
    if parsed is None:
        return _response({"detail": "Borrador inválido: estado, revisión o días."},
                         status.HTTP_400_BAD_REQUEST)
    desired_revision, days, reasons = parsed
    # Bloquear la anotación (por tenant y responsable) serializa dos PUT
    # concurrentes, incluso cuando todavía NO existe una fila de borrador.
    with transaction.atomic():
        renewal = get_object_or_404(scoped.select_for_update(), pk=renewal_id)
        if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
            return _response({"detail": "Anotación cerrada o archivada."},
                             status.HTTP_409_CONFLICT)
        current = RenewalReminderDraft.objects.filter(renewal_id=renewal.pk).first()
        actual_revision = current.revision if current is not None else 0
        if desired_revision != actual_revision:
            return _response({"detail": "Revisión obsoleta. Actualiza antes de guardar.",
                              "current_revision": actual_revision},
                             status.HTTP_409_CONFLICT)
        if reasons is None:
            reasons = {} if current is None else {k: v for k, v in current.reasons_by_day.items() if k in {str(d) for d in days}}
        # Si se persiste un borrador inicial, no se tocan las políticas
        # globales, los candidatos ni las anotaciones vecinas.
        if current is None:
            current = RenewalReminderDraft.objects.create(
                renewal=renewal, days_before=days, reasons_by_day=reasons, revision=1,
                state="draft", created_by=request.user,
                updated_by=request.user,
            )
        elif current.days_before != days or current.reasons_by_day != reasons:
            current.days_before = days
            current.reasons_by_day = reasons
            current.revision += 1
            current.updated_by = request.user
            current.save(update_fields=[
                "days_before", "reasons_by_day", "revision", "updated_by", "updated_at",
            ])
        return _response(_contract(renewal, current))
