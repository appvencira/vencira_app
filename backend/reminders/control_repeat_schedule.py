"""Transformación idempotente de una respuesta No ya registrada en aviso interno.

No implica envío, entrega ni un trabajo de background. Requiere llamada
explícita desde flujo autenticado y bajo transacción de negocio.
"""
from django.db import transaction
from .models import OperationalReminder, RenewalControlResponse
from .operational_reconcile import _event


@transaction.atomic
def plan_control_repeat(response_id, *, actor=None):
    response = RenewalControlResponse.objects.select_related(
        "renewal").get(pk=response_id)
    renewal = response.renewal
    # Lock the parent first to serialize concurrent operations per annotation.
    from .models import Renewal
    renewal = Renewal.objects.select_for_update().get(pk=renewal.pk)
    if response.answer != "no" or response.repeat_on is None:
        raise ValueError("La respuesta no solicita repetición")
    if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
        raise ValueError("No se programan controles en anotaciones cerradas")
    if renewal.modality == "vida":
        raise ValueError("Vida requiere revisión humana")
    from .legal_deadlines import one_month_before
    from django.utils import timezone
    cutoff = one_month_before(renewal.expires_on)
    if response.repeat_on > cutoff or response.repeat_on <= timezone.localdate():
        raise ValueError("La repetición no es futura o supera el límite")
    key = f"control:{response.pk}"
    existing = OperationalReminder.objects.filter(
        renewal=renewal, source_key=key, generation=1).first()
    if existing is not None:
        return existing
    reminder = OperationalReminder.objects.create(
        renewal=renewal,
        kind=OperationalReminder.Kind.CONTROL_REPEAT,
        scheduled_for=response.repeat_on,
        original_scheduled_for=response.repeat_on,
        control_question=True,
        reason="Comunicar no renovación",
        source_key=key, generation=1,
        created_by_response=response,
    )
    _event(reminder, "planned", "", actor)
    return reminder
