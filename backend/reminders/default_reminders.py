"""Whitepaper §7–8: tres avisos iniciales SIN crear mensajes ni jobs.

Esta es lógica temporal pura y NO configura automáticamente las políticas
persistentes. Los motivos comerciales se mantienen pendientes del §18.
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from .legal_deadlines import one_month_before


DEFAULT_DAYS_BEFORE = (60, 45, 35)


@dataclass(frozen=True)
class PlannedReminder:
    days_before: int
    scheduled_for: date
    has_legal_control_question: bool


def default_reminders(expires_on: date) -> tuple[PlannedReminder, ...]:
    """Tres fechas civiles y la ÚNICA pregunta de control antes del tope.

    No hay envío, entrega, aplazamiento, job ni datos personales. Si no queda
    un aviso antes del tope, no se inventa uno: asunto pendiente en §18.
    """
    if not isinstance(expires_on, date) or isinstance(expires_on, datetime):
        raise TypeError("Fecha civil requerida")
    cutoff = one_month_before(expires_on)
    dates = tuple((days, expires_on - timedelta(days=days))
                  for days in DEFAULT_DAYS_BEFORE)
    earlier = [scheduled for _, scheduled in dates if scheduled < cutoff]
    control = max(earlier) if earlier else None
    return tuple(PlannedReminder(
        days_before=days,
        scheduled_for=scheduled,
        has_legal_control_question=(control is not None and scheduled == control),
    ) for days, scheduled in dates)
