"""C2: proyección pura de acciones/avisos según decisiones C1 aprobadas.

No lee base de datos, no activa avisos ni representa cumplimiento legal.
La fecha de corte se usa solo como referencia operativa fuera de Vida.
"""
from dataclasses import dataclass
from datetime import date, timedelta

from .reminder_planning import preview_reminder_plan


@dataclass(frozen=True)
class C2ControlPolicy:
    allow_save: bool
    manual_review_required: bool
    warning_code: str | None
    warning_severity: str | None
    cutoff_on: date | None
    offer_explicit_control: bool
    latest_explicit_control_day: date | None
    future_notice_days: tuple[int, ...]
    is_life: bool
    delivery_status: str = "not_implemented"


def evaluate_c2_control_policy(
    expires_on: date, days_before: list[int] | tuple[int, ...],
    *, as_of: date, is_life: bool = False,
) -> C2ControlPolicy:
    """Always allow saving; require manual review for missing/late control.

    For Vida do not assert the general one-month cutoff applies. Any future
    control date requires human review of the policy and is not offered here.
    """
    if type(is_life) is not bool:
        raise TypeError("is_life must be bool")
    plan = preview_reminder_plan(expires_on, days_before, as_of=as_of)
    future = tuple(n.days_before for n in plan.reminders
                   if n.scheduled_for >= as_of)
    if is_life:
        return C2ControlPolicy(True, True, "life_terms_review",
                               "warning", None, False, None, future, True)
    if plan.cutoff_already_elapsed:
        return C2ControlPolicy(True, True, "civil_cutoff_reached",
                               "red", plan.cutoff_on, False, None, future, False)
    if plan.no_pre_cutoff_notice:
        warning = "no_pre_cutoff_notice"
    elif plan.late_control_needs_decision:
        warning = "control_day_elapsed"
    else:
        return C2ControlPolicy(True, False, None, None, plan.cutoff_on,
                               False, None, future, False)
    # Must be strictly before the cutoff; don't auto-schedule anything.
    last_valid_day = plan.cutoff_on - timedelta(days=1)
    offer = as_of <= last_valid_day
    return C2ControlPolicy(True, True, warning, "red",
                           plan.cutoff_on, offer,
                           last_valid_day if offer else None, future, False)
