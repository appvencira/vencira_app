"""Compatibility projection of the authoritative O9b control-response contract.

No parallel cutoff algorithm; no persistence or delivery inference.
"""
from dataclasses import dataclass
from datetime import date

from .control_responses import YES_OPTIONS, validate_control_response

YES_REASONS = frozenset(YES_OPTIONS)


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
    """Delegate to the same strict pre-cutoff rule used by the HTTP API."""
    plan = validate_control_response(
        expires_on, as_of=as_of, answer=answer,
        yes_option=reason, days_later=days_later,
    )
    return ControlIntent(
        answer=plan.answer, reason=plan.yes_option, repeat_on=plan.repeat_on,
    )
