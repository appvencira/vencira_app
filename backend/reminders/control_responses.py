"""O9b-1: pure validation of the control question (§8 / §10).

No persistence, delivery, notification, or assertion of legal compliance.
Exception cases (Life, late entry, missing eligible control) require review.
"""
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from .legal_deadlines import one_month_before

QUESTION = "¿Se ha notificado a la aseguradora su no renovación?"
YES_OPTIONS = {
    "notified_by_client": "Avisada por el cliente",
    "insurer_not_renewing": "La aseguradora no renueva",
    "notified_by_mediator": "Notificado por mí",
}
NO_REMINDER_PREFIX = "Comunicar no renovación de "


@dataclass(frozen=True)
class ControlResponsePlan:
    answer: str
    yes_option: str | None
    repeat_on: date | None
    cutoff_on: date
    question_again: bool
    notice_scheduled: bool = False
    notice_delivered: bool = False


def validate_control_response(
    expires_on: date, *, as_of: date, answer: str,
    yes_option: str | None = None, days_later: int | None = None,
    requires_manual_review: bool = False,
) -> ControlResponsePlan:
    """Validate an intended reply, not proof that the control was triggered.

    The caller must handle permission, authentication, whether a control was
    actually offered, and any special/late policy before persisting a reply.
    """
    for value in (expires_on, as_of):
        if not isinstance(value, date) or isinstance(value, datetime):
            raise TypeError("Se necesita fecha civil date")
    if type(requires_manual_review) is not bool:
        raise TypeError("Indicador de revisión inválido")
    if requires_manual_review:
        raise ValueError("Se requiere revisión manual antes de responder")
    if type(answer) is not str or answer not in ("yes", "no"):
        raise ValueError("Respuesta inválida")
    cutoff = one_month_before(expires_on)
    if answer == "yes":
        if yes_option not in YES_OPTIONS or days_later is not None:
            raise ValueError("Selecciona una de las tres opciones Sí")
        return ControlResponsePlan("yes", yes_option, None, cutoff, False)
    if yes_option is not None:
        raise ValueError("No admite opción Sí")
    if type(days_later) is not int or days_later < 1:
        raise ValueError("Selecciona un número positivo de días")
    if as_of >= cutoff:
        raise ValueError("El límite se ha alcanzado; requiere revisión manual")
    try:
        repeat_on = as_of + timedelta(days=days_later)
    except (OverflowError, ValueError):
        raise ValueError("Fecha de repetición fuera de rango") from None
    if repeat_on > cutoff:
        raise ValueError("La repetición supera el mes civil de límite")
    return ControlResponsePlan("no", None, repeat_on, cutoff, True)
