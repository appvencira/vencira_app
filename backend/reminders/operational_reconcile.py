"""Concilia ocurrencias de vencimiento en DB, sin mensajes ni tareas externas.

Debe invocarse únicamente por una operación explícita y autorizada; no desde
GET, señales automáticas, startup ni cron. La transacción bloquea la anotación.
"""
import uuid
from datetime import date
from django.db import transaction
from .models import OperationalReminder, OperationalReminderEvent, Renewal
from .operational_schedule import build_renewal_plan

ACTIVE = ("planned", "pending", "snoozed")


def _event(reminder, action, previous_state, actor=None):
    return OperationalReminderEvent.objects.create(
        reminder=reminder, actor=actor, action=action,
        previous_state=previous_state, next_state=reminder.state,
        scheduled_for=reminder.scheduled_for, idempotency_key=uuid.uuid4(),
    )


def _cancel(reminder, actor):
    before = reminder.state
    reminder.state = OperationalReminder.State.CANCELLED
    reminder.save(update_fields=["state", "updated_at"])
    _event(reminder, "cancelled", before, actor)


@transaction.atomic
def reconcile_expiry_reminders(renewal_id, *, as_of: date,
                               days_before=(60, 45, 35), actor=None):
    """Mantiene la agenda interna en consonancia sin generar envíos.

    Llamadas repetidas mantienen la identidad de las ocurrencias. Una
    reprogramación por usuario no se sobrescribe silenciosamente; si cambia
    el vencimiento se cancela la ocurrencia vieja y se crea otra generación.
    Los avisos ya completados nunca reaparecen por una simple reconciliación.
    """
    renewal = Renewal.objects.select_for_update().get(pk=renewal_id)
    history = list(OperationalReminder.objects.select_for_update().filter(
        renewal=renewal, kind=OperationalReminder.Kind.EXPIRY,
    ).order_by("generation", "created_at", "id"))

    if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
        desired = {}
    else:
        plan = build_renewal_plan(
            renewal.expires_on, today=as_of, days_before=days_before,
            life_insurance=renewal.modality == "vida")
        if plan.manual_review_required or plan.no_pre_cutoff_control or plan.late_control:
            raise ValueError("La anotación requiere revisión humana antes de programar")
        desired = {
            f"expiry:{occ.days_before}": occ
            for occ in plan.occurrences
        }

    active_by_key = {}
    history_by_key = {}
    for item in history:
        history_by_key.setdefault(item.source_key, []).append(item)
        if item.state in ACTIVE:
            active_by_key[item.source_key] = item

    result = []
    for key, occurrence in desired.items():
        current = active_by_key.get(key)
        previous = history_by_key.get(key, [])
        if current is not None and (
            current.original_scheduled_for != occurrence.day or
            current.control_question != occurrence.control_question
        ):
            _cancel(current, actor)
            current = None
        if current is None:
            last = previous[-1] if previous else None
            if (last is not None and
                last.state == OperationalReminder.State.COMPLETED and
                last.original_scheduled_for == occurrence.day):
                result.append(last)
                continue
            generation = max((row.generation for row in previous), default=0) + 1
            current = OperationalReminder.objects.create(
                renewal=renewal, kind=OperationalReminder.Kind.EXPIRY,
                source_key=key, generation=generation,
                days_before=occurrence.days_before,
                scheduled_for=occurrence.day,
                original_scheduled_for=occurrence.day,
                control_question=occurrence.control_question,
                reason="Aviso de vencimiento",
            )
            _event(current, "planned", "", actor)
        result.append(current)

    for item in history:
        if item.state in ACTIVE and (item.source_key not in desired or
                item not in result):
            _cancel(item, actor)
    return tuple(result)
