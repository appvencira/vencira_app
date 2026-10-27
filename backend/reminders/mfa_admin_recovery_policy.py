"""D1.5-S1: política pura de revisión de recuperación MFA (NO realiza reset).

Evaluador fail-closed. No endpoint, no mutaciones ni autorización automática.
La persistencia/auditoría y verificación externa deberán implementarse antes de
usar el veredicto en una operación administrativa.
"""
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

MAX_CASE_AGE = timedelta(hours=24)
MIN_QUARANTINE = timedelta(hours=24)


@dataclass(frozen=True)
class RecoveryApproval:
    reviewer_id: int
    case_id: str
    expires_at: datetime


@dataclass(frozen=True)
class RecoveryCase:
    case_id: str
    subject_id: int
    requester_id: int
    created_at: datetime
    quarantine_until: datetime
    channel_verified: bool
    approvals: tuple[RecoveryApproval, ...]
    status: str = "pending"


def assess_recovery(case: RecoveryCase, *, now: datetime) -> tuple[bool, str]:
    """Precondiciones mínimas; NO significa que la recuperación esté autorizada."""
    if not isinstance(now, datetime) or now.tzinfo is None:
        return False, "INVALID_CLOCK"
    if not isinstance(case, RecoveryCase) or not case.case_id:
        return False, "INVALID_CASE"
    dates = (case.created_at, case.quarantine_until)
    if any(not isinstance(d, datetime) or d.tzinfo is None for d in dates):
        return False, "INVALID_DATES"
    if case.status != "pending":
        return False, "CASE_NOT_PENDING"
    if case.subject_id <= 0 or case.requester_id <= 0:
        return False, "INVALID_ACTOR"
    if case.created_at > now or now - case.created_at > MAX_CASE_AGE:
        return False, "CASE_EXPIRED"
    if case.quarantine_until < case.created_at + MIN_QUARANTINE:
        return False, "QUARANTINE_TOO_SHORT"
    if now < case.quarantine_until:
        return False, "QUARANTINE_ACTIVE"
    if not case.channel_verified:
        return False, "UNVERIFIED_INDEPENDENT_CHANNEL"
    if len(case.approvals) != 2:
        return False, "TWO_APPROVALS_REQUIRED"
    reviewers = [a.reviewer_id for a in case.approvals]
    if any(a.case_id != case.case_id for a in case.approvals):
        return False, "CROSS_CASE_APPROVAL"
    if any(a.expires_at.tzinfo is None or a.expires_at <= now for a in case.approvals):
        return False, "EXPIRED_APPROVAL"
    if len(set(reviewers)) != 2 or any(i <= 0 for i in reviewers):
        return False, "REVIEWERS_NOT_DISTINCT"
    if case.requester_id in reviewers or case.subject_id in reviewers:
        return False, "CONFLICT_OF_INTEREST"
    return True, "POLICY_PRECONDITIONS_MET_ONLY"
