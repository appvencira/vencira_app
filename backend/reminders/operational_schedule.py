"""Macrobloque A: motor civil puro de avisos (whitepaper §§7–10).

No consulta DB, no agenda tareas, no envía mensajes ni presume entrega.
Separar este cálculo de activación, deduplicación y persistencia.
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from .legal_deadlines import one_month_before

DEFAULT_DAYS = (60, 45, 35)
DEFAULT_TIME = "09:00"


@dataclass(frozen=True)
class PlannedOccurrence:
    days_before: int
    day: date
    control_question: bool
    overdue_at_creation: bool = False


@dataclass(frozen=True)
class RenewalPlan:
    expiry: date
    cutoff: date
    occurrences: tuple[PlannedOccurrence, ...]
    manual_review_required: bool
    no_pre_cutoff_control: bool
    late_control: bool


def build_renewal_plan(
    expiry: date, *, today: date, days_before=DEFAULT_DAYS,
    life_insurance: bool = False,
) -> RenewalPlan:
    """Calcula avisos sin simular avisos pasados ni decidir excepciones jurídicas.

    La pregunta corresponde al último aviso estrictamente anterior al
    límite civil. Si el aviso pasado no puede programarse retroactivamente,
    la situación requiere decisión manual, nunca una notificación ficticia.
    """
    if (type(expiry) is not date or type(today) is not date
            or type(life_insurance) is not bool):
        raise TypeError("Se requieren fechas civiles y un indicador Vida booleano")
    if not isinstance(days_before, (list, tuple)):
        raise TypeError("Días de aviso inválidos")
    if not 1 <= len(days_before) <= 12 or any(
        type(v) is not int or not 0 <= v <= 365 for v in days_before
    ) or len(set(days_before)) != len(days_before):
        raise ValueError("Se requieren entre 1 y 12 días únicos de 0 a 365")
    cutoff = one_month_before(expiry)
    ordered = tuple(sorted(days_before, reverse=True))
    candidates = [(d, expiry - timedelta(days=d)) for d in ordered]
    eligible = [day for _, day in candidates if day < cutoff]
    control_on = max(eligible) if eligible else None
    occurrences = tuple(
        PlannedOccurrence(d, day, day == control_on, day < today)
        for d, day in candidates if day >= today
    )
    return RenewalPlan(
        expiry=expiry, cutoff=cutoff, occurrences=occurrences,
        manual_review_required=life_insurance,
        no_pre_cutoff_control=control_on is None,
        late_control=control_on is not None and control_on < today,
    )


def repeat_control_day(*, today: date, expiry: date, days_later: int,
                       life_insurance: bool = False) -> date:
    """El No solicita una fecha civil dentro del plazo; no realiza el envío."""
    if type(today) is not date or type(expiry) is not date:
        raise TypeError("Fechas civiles requeridas")
    if type(life_insurance) is not bool or life_insurance:
        raise ValueError("Vida: requiere revisión humana")
    if type(days_later) is not int or days_later < 1:
        raise ValueError("Días futuros positivos requeridos")
    cutoff = one_month_before(expiry)
    if today >= cutoff:
        raise ValueError("Límite civil alcanzado")
    try:
        day = today + timedelta(days=days_later)
    except OverflowError:
        raise ValueError("Fecha no representable") from None
    if day > cutoff:
        raise ValueError("Fecha posterior al límite civil")
    return day
