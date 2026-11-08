"""I8-B test-only storage and one-time retirement of opaque MFA challenges.

The caller has NOT proved a password by invoking create_pending_candidate_challenge.
Retirement is NOT MFA verification and NEVER returns a session/issuance grant.
No HTTP routes; full authentication protocol is intentionally unfinished.
"""
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from reminders.native_mobile_identity_gate import mobile_credential_version

from .candidate_challenge_wire import (
    NativeChallengeMalformed, matches_candidate_digest,
    new_candidate_challenge, parse_candidate_challenge,
)
from .models import MobileAccountFence, MobilePendingChallenge
from .session_store import MobileTokenDenied, _gate


class CandidateChallengeDenied(Exception):
    """No account/challenge-state details leave the candidate boundary."""


def _require_lab():
    try:
        _gate()
    except MobileTokenDenied:
        raise CandidateChallengeDenied() from None


def _state(user):
    state = UserMfaState.objects.select_for_update().filter(
        user_id=user.pk, enabled=True,
    ).first()
    if state is None:
        raise CandidateChallengeDenied()
    cases = MfaAdministrativeRecoveryCase.objects.filter(subject_id=user.pk)
    if cases.filter(status=MfaAdministrativeRecoveryCase.Status.PENDING).exists():
        raise CandidateChallengeDenied()
    return state


def _generation(user_id):
    row = MobileAccountFence.objects.filter(user_id=user_id).first()
    return row.generation if row is not None else 0


def create_pending_candidate_challenge(*, user_id, ttl_seconds=300):
    """Return opaque wire secret after storing its hash; NOT password authorization.

    Called by trusted isolated test setup only; an operational pre-auth issuer
    MUST establish password/admission/audit security before using this concept.
    """
    _require_lab()
    if type(user_id) is not int or user_id <= 0 or type(ttl_seconds) is not int or not 1 <= ttl_seconds <= 300:
        raise CandidateChallengeDenied()
    try:
        with transaction.atomic():
            user = get_user_model().objects.select_for_update().filter(
                pk=user_id, is_active=True,
            ).first()
            if user is None:
                raise CandidateChallengeDenied()
            state = _state(user)
            wire, challenge_id, digest = new_candidate_challenge()
            MobilePendingChallenge.objects.create(
                id=challenge_id, user=user, secret_digest=digest,
                credential_version=mobile_credential_version(user),
                mfa_epoch=state.session_epoch,
                auth_generation=_generation(user.pk),
                expires_at=timezone.now() + timedelta(seconds=ttl_seconds),
            )
            return wire
    except NativeChallengeMalformed:
        raise CandidateChallengeDenied() from None


def retire_pending_candidate_challenge(*, wire):
    """Atomically retire only a still-valid challenge. Returns None, not auth.

    Lock ordering: User -> MFA state -> Challenge, consistent with I7-B
    user-first serialization. A retirement cannot be used as TOTP evidence.
    """
    _require_lab()
    try:
        challenge_id, _ = parse_candidate_challenge(wire)
    except NativeChallengeMalformed:
        raise CandidateChallengeDenied() from None
    with transaction.atomic():
        # A preliminary lookup only discovers the account ID. All security
        # decisions happen after the user row has been locked.
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
        row.consumed_at = now
        row.save(update_fields=["consumed_at"])
    return None
