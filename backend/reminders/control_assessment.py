"""O9a: lectura PREVIA de la pregunta de control. Nunca pregunta ni envía.

El blanco del whitepaper §8 es el último aviso anterior al límite
informativo de un mes civil. No se inventa una respuesta, entrega, intervalo
ni solución para Vida / avisos tardíos / cero avisos elegibles (§18).
"""
from dataclasses import dataclass
from datetime import date, datetime

from .reminder_planning import preview_reminder_plan


@dataclass(frozen=True)
class ControlAssessment:
    status: str
    control_day: date | None
    cutoff_on: date
    reference_day: date
    reasons: tuple[str, ...]
    control_days_before: int | None


def assess_control(
    expires_on: date,
    days_before: list[int] | tuple[int, ...],
    *,
    as_of: date,
    requires_life_review: bool = False,
) -> ControlAssessment:
    """Civil-day deterministic projection, no DB queries or writes."""
    if type(requires_life_review) is not bool:
        raise TypeError("life flag must be boolean")
    plan = preview_reminder_plan(expires_on, days_before, as_of=as_of)
    control = next((n for n in plan.reminders if n.control_question), None)
    reasons = []
    if requires_life_review:
        reasons.append("life_case_needs_review")
    if control is None:
        reasons.append("no_notice_before_cutoff")
    if plan.cutoff_already_elapsed:
        reasons.append("informational_cutoff_reached")
    if control is not None and control.scheduled_for < as_of:
        reasons.append("control_date_already_past_no_execution_evidence")

    if reasons:
        state = "manual_review_required"
    elif control.scheduled_for == as_of:
        state = "control_day_today_preview"
    else:
        state = "control_day_future_preview"

    return ControlAssessment(
        status=state,
        control_day=control.scheduled_for if control else None,
        cutoff_on=plan.cutoff_on,
        reference_day=plan.reference_day,
        reasons=tuple(reasons),
        control_days_before=control.days_before if control else None,
    )
