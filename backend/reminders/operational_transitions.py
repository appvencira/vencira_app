"""Transiciones de avisos internos: sin canales ni pruebas de entrega.

Invocar solo desde API autenticada con verificación de pertenencia/visibilidad.
Las acciones se serializan con bloqueo de la anotación y CAS sobre estado/fecha.
"""
import uuid
from datetime import timedelta
from django.db import transaction
from django.utils import timezone
from .models import OperationalReminder, OperationalReminderEvent, Renewal
from .operational_reconcile import ACTIVE


class ReminderConflict(ValueError):
    """La operación requiere recargar los datos antes de reintentar."""


@transaction.atomic
def transition_reminder(*, renewal_id, reminder_id, action, expected_state,
                        expected_day, idempotency_key, actor, days_later=None,
                        as_of=None):
    if type(idempotency_key) is not uuid.UUID:
        raise ValueError("Clave idempotente UUID requerida")
    if action not in ("complete", "tomorrow", "another_day"):
        raise ValueError("Acción inválida")
    if expected_state not in ACTIVE:
        raise ValueError("Estado previo inválido")
    if type(expected_day) is not type(timezone.localdate()):
        raise ValueError("Fecha civil previa inválida")
    if action == "complete" and days_later is not None:
        raise ValueError("Completada no requiere días")
    if action == "tomorrow" and days_later is not None:
        raise ValueError("Mañana no requiere días")
    if action == "another_day" and (
        type(days_later) is not int or days_later < 2 or days_later > 365
    ):
        raise ValueError("Otro día exige entre 2 y 365 días")
    today = timezone.localdate() if as_of is None else as_of
    if type(today) is not type(expected_day):
        raise ValueError("Fecha de ejecución inválida")
    renewal = Renewal.objects.select_for_update().get(pk=renewal_id)
    reminder = OperationalReminder.objects.select_for_update().get(
        pk=reminder_id, renewal=renewal)
    previous = OperationalReminderEvent.objects.filter(
        reminder=reminder, idempotency_key=idempotency_key).first()
    if previous is not None:
        if (previous.action != action or
            previous.previous_state != expected_state or
            (action == "complete" and previous.next_state != "completed")):
            raise ReminderConflict("Clave ya utilizada para otra acción")
        return reminder
    if renewal.status == Renewal.Status.CLOSED or renewal.archived_at:
        raise ReminderConflict("La anotación ya no está activa")
    if reminder.state != expected_state or reminder.scheduled_for != expected_day:
        raise ReminderConflict("Estado o fecha modificados; recarga la anotación")
    if action == "complete":
        new_state = OperationalReminder.State.COMPLETED
        new_day = reminder.scheduled_for
    else:
        offset = 1 if action == "tomorrow" else days_later
        new_day = today + timedelta(days=offset)
        if reminder.control_question:
            from .legal_deadlines import one_month_before
            if renewal.modality == "vida" or new_day > one_month_before(renewal.expires_on):
                raise ValueError("Aplazamiento fuera del límite civil; revisión humana")
        new_state = OperationalReminder.State.SNOOZED
    reminder.state = new_state
    reminder.scheduled_for = new_day
    reminder.save(update_fields=["state", "scheduled_for", "updated_at"])
    OperationalReminderEvent.objects.create(
        reminder=reminder, actor=actor, action=action,
        previous_state=expected_state, next_state=new_state,
        scheduled_for=new_day, idempotency_key=idempotency_key,
    )
    return reminder
