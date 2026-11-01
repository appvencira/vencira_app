"""O8b: vista previa PURA de avisos personalizados del whitepaper §7–8.

NO persiste avisos, NO envía notificaciones, NO interpreta Vida ni garantiza
un plazo legal concreto. Las decisiones tardías y sin control se indican,
nunca se resuelven automáticamente sin la aprobación del promotor (§18).
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from .default_reminders import DEFAULT_DAYS_BEFORE
from .legal_deadlines import one_month_before


MAX_RULES = 12
MAX_DAYS_BEFORE = 365


@dataclass(frozen=True)
class PreviewReminder:
    days_before: int
    scheduled_for: date
    before_cutoff: bool
    control_question: bool
    already_elapsed: bool


@dataclass(frozen=True)
class ReminderPreviewPlan:
    expires_on: date
    reference_day: date
    cutoff_on: date
    reminders: tuple[PreviewReminder, ...]
    no_pre_cutoff_notice: bool
    late_control_needs_decision: bool
    cutoff_already_elapsed: bool


def _civil_day(value):
    if not isinstance(value, date) or isinstance(value, datetime):
        raise TypeError("Debe indicarse una fecha civil date")
    return value


def preview_reminder_plan(
    expires_on: date,
    days_before=DEFAULT_DAYS_BEFORE,
    *,
    as_of: date,
) -> ReminderPreviewPlan:
    """Una plantilla por anotación; no habilita reglas persistentes globales.

    Se considera transcurrido un aviso si su fecha es estrictamente anterior
    a as_of. Si el último aviso de control ya pasó, se marca para decisión
    manual; no se "envía" retroactivamente ni se inventa otro aviso.
    """
    _civil_day(expires_on)
    _civil_day(as_of)
    if not isinstance(days_before, (list, tuple)) or not 1 <= len(days_before) <= MAX_RULES:
        raise ValueError("Se necesitan entre 1 y 12 avisos")
    if any(type(n) is not int or not 0 <= n <= MAX_DAYS_BEFORE
           for n in days_before):
        raise ValueError("Los días deben ser enteros entre 0 y 365")
    if len(set(days_before)) != len(days_before):
        raise ValueError("No se permiten anticipaciones duplicadas")
    cutoff = one_month_before(expires_on)
    sorted_days = sorted(days_before, reverse=True)
    dates = tuple((n, expires_on - timedelta(days=n)) for n in sorted_days)
    eligible = [day for _, day in dates if day < cutoff]
    control = max(eligible) if eligible else None
    reminders = tuple(PreviewReminder(
        days_before=n,
        scheduled_for=day,
        before_cutoff=day < cutoff,
        control_question=control is not None and day == control,
        already_elapsed=day < as_of,
    ) for n, day in dates)
    return ReminderPreviewPlan(
        expires_on=expires_on,
        reference_day=as_of,
        cutoff_on=cutoff,
        reminders=reminders,
        no_pre_cutoff_notice=control is None,
        late_control_needs_decision=control is not None and control < as_of,
        cutoff_already_elapsed=cutoff <= as_of,
    )


def validate_control_repeat_day(expires_on: date, *, as_of: date, days_later: int) -> date:
    """Para una respuesta «No», el siguiente control nunca supera el tope.

    No escoge automáticamente ningún intervalo, ni genera tareas; el mismo
    día del tope ya no permite programar un seguimiento futuro.
    """
    _civil_day(expires_on)
    _civil_day(as_of)
    if type(days_later) is not int or not 1 <= days_later <= 365:
        raise ValueError("Intervalo inválido")
    cutoff = one_month_before(expires_on)
    if as_of >= cutoff:
        raise ValueError("El límite civil está alcanzado")
    try:
        scheduled = as_of + timedelta(days=days_later)
    except OverflowError:
        raise ValueError("Fecha de repetición no representable") from None
    if scheduled >= cutoff:
        raise ValueError("No se permite repetir en el límite civil ni después")
    return scheduled
