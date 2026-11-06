"""I7-B: disposable PG17 MFA verification+issuance transaction prototype.

No HTTP handler, no password-only bypass, no production key custody and NO
authority to issue a live session. Test-only candidate registration is enforced
by session_store._gate(). Callers must not use test results as MFA release proof.
"""
import uuid

from django.contrib.auth import get_user_model
from django.db import transaction
from reminders.models import UserMfaState

from .g14_admission import admit_candidate_password_attempt
from .g14_e1_locked_mfa_verifier import (
    CandidateMfaDenied, verify_candidate_password_and_totp,
)
from .g5_audit import record_candidate_auth_event
from .session_store import (
    MobileTokenDenied, _gate, _generation, issue_verified_candidate_session,
)


def candidate_mfa_atomic_flow(*, username, password, code, keys,
                              request_meta, event_id, timestamp=None):
    """Use ONE account lock across TOTP consumption, token insert and audit.

    An in-process boolean verification result is not accepted from the caller:
    this routine invokes the existing password+TOTP writer itself under the
    same outer transaction. An audit failure rolls back BOTH the accepted
    counter and the device session. Caller-provided keys/timestamps make this
    a test-only candidate, not a production TOTP trust boundary.
    """
    _gate()
    if type(event_id) is not uuid.UUID:
        raise ValueError("Invalid synthetic attempt identifier")
    if not admit_candidate_password_attempt(
        account_key=username, request_meta=request_meta,
        denial_event_id=event_id,
    ):
        return None

    try:
        with transaction.atomic():
            User = get_user_model()
            if User.USERNAME_FIELD != "username" or type(username) is not str:
                raise CandidateMfaDenied()
            user = User.objects.select_for_update().filter(
                username=username, is_active=True,
            ).first()
            if user is None:
                raise CandidateMfaDenied()

            # Nested atomic verification shares the lock and transaction.
            verified = verify_candidate_password_and_totp(
                username=username, password=password, code=code,
                keys=keys, timestamp=timestamp,
            )
            if verified is not True:
                raise CandidateMfaDenied()

            state = UserMfaState.objects.select_for_update().filter(
                user_id=user.pk, enabled=True,
            ).first()
            if state is None:
                raise CandidateMfaDenied()
            generation = _generation(user.pk)
            pair = issue_verified_candidate_session(
                user_id=user.pk, verified_mfa=True,
                mfa_epoch=state.session_epoch,
                expected_generation=generation,
            )
            _, created = record_candidate_auth_event(
                event_id=event_id, event_type="auth_verified",
                actor=username,
            )
            if not created:
                raise ValueError("Duplicate MFA candidate attempt identifier")
            return pair
    except (CandidateMfaDenied, MobileTokenDenied):
        # If denial is detected AFTER consuming a factor, this separate audit
        # commits only after the failed outer transaction has rolled back.
        record_candidate_auth_event(
            event_id=event_id, event_type="auth_denied", actor=username,
        )
        return None
