"""G14: candidate-only pre-verification admission gate.

No password/MFA verification, token issuance, HTTP route, or production integration.
Both account/IP throttling and audit readiness must be available. On a denied
attempt a minimal audit event is recorded in the SAME disposable transaction.
"""
import uuid

from django.db import transaction

from .g5_audit import MobileAuditDenied, _key as require_audit_key
from .g5_audit import record_candidate_auth_event
from .g5_throttle import CandidateThrottleDenied, consume_candidate_auth_attempt


class CandidateAdmissionDenied(Exception):
    """Uniform failure; caller must never proceed to verify credentials."""


def admit_candidate_password_attempt(
    *, account_key, request_meta, denial_event_id, trusted_proxy_ips=(),
):
    """Return True for a budgeted attempt, False on rate limit.

    The return value is NOT authentication. If audit infrastructure is missing,
    the entire operation fails closed BEFORE credential verification. Account
    identity normalization is caller responsibility, same for unknown users.
    This never accepts a proof of password/MFA or yields a session.
    """
    if type(denial_event_id) is not uuid.UUID:
        raise CandidateAdmissionDenied()
    try:
        with transaction.atomic():
            # Audit key readiness must be checked even on an allowed attempt.
            require_audit_key()
            permitted = consume_candidate_auth_attempt(
                account_key=account_key,
                request_meta=request_meta,
                trusted_proxy_ips=trusted_proxy_ips,
            )
            if not permitted:
                record_candidate_auth_event(
                    event_id=denial_event_id,
                    event_type="auth_denied",
                    actor=account_key,
                )
            return permitted
    except (MobileAuditDenied, CandidateThrottleDenied) as exc:
        raise CandidateAdmissionDenied() from exc
