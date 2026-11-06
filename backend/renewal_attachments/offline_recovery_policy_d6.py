"""D6B: decisiones puras para recuperación de adjuntos.

Sin accesos a archivos, base de datos, endpoints ni transiciones
persistentes. Ninguna decisión concede descarga o cierre automático.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class RecoveryDecision:
    classification: str
    action: str
    terminal: bool = False
    release_authorized: bool = False


POLICY = {
    "verified": "reconcile_metadata",
    "missing": "review_missing_object",
    "unavailable": "retry_when_store_available",
    "invalid": "quarantine_and_investigate",
}


def decide_recovery(classification):
    if not isinstance(classification, str):
        raise ValueError("INVALID_RECOVERY_CLASSIFICATION")

    if classification not in POLICY:
        raise ValueError("UNKNOWN_RECOVERY_CLASSIFICATION")

    return RecoveryDecision(
        classification=classification,
        action=POLICY[classification],
    )


def retry_decision(previous, classification):
    """Reevaluación sin mutaciones; repetir entradas no cambia el resultado."""
    if not isinstance(previous, RecoveryDecision):
        raise ValueError("INVALID_PREVIOUS_DECISION")

    if previous.terminal or previous.release_authorized:
        raise ValueError("UNAUTHORIZED_TERMINAL_DECISION")

    return decide_recovery(classification)
