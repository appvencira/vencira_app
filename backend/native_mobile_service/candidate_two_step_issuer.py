"""I8-C candidate-only two-stage password -> MFA -> atomic native issuance.

NO HTTP endpoints, device access, production key custody or release. Callers
provide lab-only TOTP keys/timestamps. A successful wire challenge does not
authenticate: all authority is evaluated under PostgreSQL account locks.
"""
import uuid
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from reminders.mfa_store import consume_totp
from reminders.native_mobile_identity_gate import mobile_credential_version
from .candidate_challenge_store import (
    CandidateChallengeDenied, _generation, _require_lab, _state,
)
from .candidate_challenge_wire import (
    NativeChallengeMalformed, matches_candidate_digest,
    new_candidate_challenge, parse_candidate_challenge,
)
from .g14_admission import admit_candidate_password_attempt
from .g5_audit import record_candidate_auth_event
from .models import MobilePendingChallenge
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session,
)


def candidate_password_to_challenge(*, username, password, request_meta,
                                    event_id, ttl_seconds=300):
    """Test-only password stage; return opaque challenge or None.

    All candidate password attempts consume G5 account/IP budgets. The
    password is verified inside a user lock; no authenticated session exists.
    """
    _require_lab()
    if (type(username) is not str or not username or username != username.strip()
            or len(username) > 150 or type(password) is not str or not password
            or len(password) > 4096 or type(event_id) is not uuid.UUID
            or type(ttl_seconds) is not int or not 1 <= ttl_seconds <= 300):
        raise CandidateChallengeDenied()
    if not admit_candidate_password_attempt(
        account_key=username, request_meta=request_meta,
        denial_event_id=event_id,
    ):
        return None
    with transaction.atomic():
        User = get_user_model()
        if User.USERNAME_FIELD != "username":
            raise CandidateChallengeDenied()
        user = User.objects.select_for_update().filter(
            username=username, is_active=True,
        ).first()
        if user is None or not user.check_password(password):
            record_candidate_auth_event(
                event_id=event_id, event_type="auth_denied", actor=username,
            )
            return None
        try:
            state = _state(user)
        except CandidateChallengeDenied:
            record_candidate_auth_event(
                event_id=event_id, event_type="auth_denied", actor=username,
            )
            return None
        wire, challenge_id, digest = new_candidate_challenge()
        MobilePendingChallenge.objects.create(
            id=challenge_id, user=user, secret_digest=digest,
            credential_version=mobile_credential_version(user),
            mfa_epoch=state.session_epoch,
            auth_generation=_generation(user.pk),
            expires_at=timezone.now() + timedelta(seconds=ttl_seconds),
        )
        return wire


def candidate_mfa_challenge_to_session(*, wire, code, keys, event_id,
                                       timestamp=None):
    """Consume challenge, TOTP, insert device session and audit atomically.

    Wrong TOTP retains the challenge (G5 budget is consumed on password step)
    and commits the MFA failed-attempt counter plus auth_denied audit. Audit
    failure on a successful factor rolls back challenge and TOTP consumption.
    This function never accepts a caller-supplied 'MFA verified' assertion.
    """
    _require_lab()
    if (type(event_id) is not uuid.UUID or type(code) is not str
            or len(code) != 6 or not code.isascii() or not code.isdecimal()
            or type(keys) is not list or not keys):
        raise CandidateChallengeDenied()
    try:
        challenge_id, _ = parse_candidate_challenge(wire)
    except NativeChallengeMalformed:
        raise CandidateChallengeDenied() from None
    with transaction.atomic():
        owner_id = MobilePendingChallenge.objects.filter(
            pk=challenge_id,
        ).values_list("user_id", flat=True).first()
        if owner_id is None:
            raise CandidateChallengeDenied()
        user = get_user_model().objects.select_for_update().filter(
            pk=owner_id, is_active=True,
        ).first()
        if user is None:
            raise CandidateChallengeDenied()
        state = _state(user)
        row = MobilePendingChallenge.objects.select_for_update().filter(
            pk=challenge_id, user_id=user.pk,
        ).first()
        now = timezone.now()
        if (row is None or row.consumed_at is not None or row.expires_at <= now
                or row.credential_version != mobile_credential_version(user)
                or row.mfa_epoch != state.session_epoch
                or row.auth_generation != _generation(user.pk)
                or not matches_candidate_digest(
                    wire, expected_id=row.pk, stored_digest=row.secret_digest,
                )):
            raise CandidateChallengeDenied()

        # Use the existing MFA writer within this *same* outer transaction.
        # Any unexpected decrypt/DB error rolls back all writes.
        if not consume_totp(user.pk, code, keys=keys, timestamp=timestamp):
            record_candidate_auth_event(
                event_id=event_id, event_type="auth_denied",
                actor=user.username,
            )
            return None

        row.consumed_at = now
        row.save(update_fields=["consumed_at"])
        pair = issue_verified_candidate_session(
            user_id=user.pk, verified_mfa=True,
            mfa_epoch=state.session_epoch,
            expected_generation=row.auth_generation,
        )
        _, created = record_candidate_auth_event(
            event_id=event_id, event_type="auth_verified",
            actor=user.username,
        )
        if not created:
            raise CandidateChallengeDenied()
        return pair
