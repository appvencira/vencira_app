"""M3-02: pure, fail-closed validation of control question intents.

This module does not save, send or assert that the insurer was notified.
"""
from dataclasses import dataclass
from datetime import date, datetime

from .reminder_planning import validate_control_repeat_day

YES_REASONS = frozenset((
    "notified_by_client", "insurer_not_renewing", "notified_by_mediator",
))

@dataclass(frozen=True)
class ControlIntent:
    answer: str
    reason: str | None
    repeat_on: date | None
    verified_delivery: bool = False
    closes_renewal: bool = False


def validate_control_intent(*, expires_on: date, as_of: date,
                            answer: str, reason: str | None = None,
                            days_later: int | None = None) -> ControlIntent:
    """Validate an explicit human answer without any side effects.

    The repeat deadline is a civil month before expiry, not 30 days.
    The caller must separately authorize, persist and audit an intent.
    """
    if type(answer) is not str or answer not in ("yes", "no"):
        raise ValueError("CONTROL_ANSWER_INVALID")
    if answer == "yes":
        if reason not in YES_REASONS or days_later is not None:
            raise ValueError("CONTROL_YES_REASON_INVALID")
        if not isinstance(as_of, date) or isinstance(as_of, datetime):
            raise ValueError("CONTROL_DATE_INVALID")
        if not isinstance(expires_on, date) or isinstance(expires_on, datetime):
            raise ValueError("CONTROL_DATE_INVALID")
        return ControlIntent(answer="yes", reason=reason, repeat_on=None)
    if reason is not None:
        raise ValueError("CONTROL_NO_REASON_FORBIDDEN")
    when = validate_control_repeat_day(
        expires_on, as_of=as_of, days_later=days_later,
    )
    return ControlIntent(answer="no", reason=None, repeat_on=when)
