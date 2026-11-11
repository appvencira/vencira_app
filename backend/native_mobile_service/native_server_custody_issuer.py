"""D21 server-custodied native MFA issuance service, isolated candidate.

This is a real composition of locked password -> TOTP -> token issuance and
account-wide recovery operations, not an evidence/flag-only gate. The session
store remains explicitly test-only, the operational issuer is not registered,
and no public URLs or client-supplied key/timestamp are accepted.

Important: this module is *not* authorization to deploy mobile credentials.
"""
import uuid

from django.conf import settings

from reminders.mfa_key_config import load_mfa_keys

from .candidate_challenge_store import CandidateChallengeDenied, _require_lab
from .candidate_two_step_issuer import (
    candidate_password_to_challenge,
    candidate_mfa_challenge_to_session,
)
from .candidate_recovery_issuer import (
    recovery_password_to_challenge,
    recovery_mfa_to_atomic_session,
)


class NativeServerIssuerUnavailable(PermissionError):
    """Uniform caller-visible denial; never disclose secret/key state."""


def _guard():
    # Deliberate lock even if an operator sets unrelated release flags.
    try:
        _require_lab()
    except CandidateChallengeDenied:
        raise NativeServerIssuerUnavailable("Mobile issuer unavailable") from None
    if (
        settings.VENCIRA_ENV != "test"
        or not settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        or settings.VENCIRA_NATIVE_BEARER_ENABLED
    ):
        raise NativeServerIssuerUnavailable("Mobile issuer unavailable")


def _keys():
    _guard()
    try:
        # Same server-owned custody provider as Django's web MFA.
        # Never accept encryption keys or a clock from a request or caller.
        return load_mfa_keys()
    except (ValueError, OSError):
        raise NativeServerIssuerUnavailable("Mobile issuer unavailable") from None


def _event():
    return uuid.uuid4()


def begin_native_password(*, username, password, request_meta):
    """Issue opaque MFA challenge only after real password/admission checks."""
    _guard()
    return candidate_password_to_challenge(
        username=username, password=password,
        request_meta=request_meta, event_id=_event(),
    )


def complete_native_mfa(*, challenge, code):
    """Server-side MFA keyring + PG account lock + anti-replay + issuance."""
    keys = _keys()
    return candidate_mfa_challenge_to_session(
        wire=challenge, code=code, keys=keys, event_id=_event(),
    )


def begin_native_recovery(*, username, password, request_meta):
    """Recovery-only challenge; password can never issue mobile credentials."""
    _guard()
    return recovery_password_to_challenge(
        username=username, password=password,
        request_meta=request_meta, event_id=_event(),
    )


def complete_native_recovery(*, challenge, code):
    """Server-custodied MFA and atomic account-wide revoke + new session."""
    keys = _keys()
    return recovery_mfa_to_atomic_session(
        wire=challenge, code=code, keys=keys, event_id=_event(),
    )
