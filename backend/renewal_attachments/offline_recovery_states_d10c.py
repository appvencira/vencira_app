"""D10C: política pura de estados para recuperación.

No persiste cambios. No habilita operaciones de documentos.
La persistencia y coordinación PG17 requieren otro gate.
"""
from dataclasses import dataclass

from .offline_recovery_policy_d6 import decide_recovery


@dataclass(frozen=True)
class RecoveryState:
    classification: str
    status: str
    action: str
    release_authorized: bool = False


VALID_STATUSES = frozenset({
    "pending", "review_required", "retry_required",
    "resolved_manually",
})


def evaluate_recovery(classification):
    decision = decide_recovery(classification)
    status = (
        "retry_required"
        if classification == "unavailable"
        else "review_required"
    )
    return RecoveryState(
        classification=classification,
        status=status,
        action=decision.action,
    )


def transition_recovery(previous, target, *, manual_approval=False):
    if not isinstance(previous, RecoveryState):
        raise ValueError("INVALID_PREVIOUS_STATE")
    if (
        previous.status not in VALID_STATUSES
        or previous.release_authorized
    ):
        raise ValueError("UNTRUSTED_RECOVERY_STATE")

    if target == previous.status:
        return previous

    if previous.status == "resolved_manually":
        raise ValueError("TERMINAL_STATE")

    if target == "resolved_manually":
        if (
            not manual_approval
            or previous.status != "review_required"
        ):
            raise ValueError("MANUAL_APPROVAL_REQUIRED")
        return RecoveryState(
            previous.classification,
            "resolved_manually",
            previous.action,
        )

    if target in {"review_required", "retry_required"}:
        if previous.status not in {
            "pending", "retry_required", "review_required"
        }:
            raise ValueError("INVALID_TRANSITION")
        return RecoveryState(
            previous.classification,
            target,
            previous.action,
        )

    raise ValueError("INVALID_TRANSITION")
