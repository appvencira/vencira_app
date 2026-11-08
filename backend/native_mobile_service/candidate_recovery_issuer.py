"""I8-J test-only account recovery: fresh password+TOTP and atomic revoke.

No HTTP routing, operational key custody, live database or release.
Recovery challenge digests are domain-separated from normal login without
changing the candidate schema. A regular lc1 challenge cannot be promoted
to an account-wide recovery grant by editing the wire string.
"""
import hashlib
import hmac
import uuid
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import F
from django.utils import timezone

from reminders.mfa_store import consume_totp
from reminders.native_mobile_identity_gate import mobile_credential_version

from .candidate_challenge_store import (
    CandidateChallengeDenied, _generation, _require_lab, _state,
)
from .candidate_challenge_wire import (
    NativeChallengeMalformed, new_candidate_challenge, parse_candidate_challenge,
)
from .g14_admission import admit_candidate_password_attempt
from .g5_audit import record_candidate_auth_event
from .models import (
    MobileAccountFence, MobileDeviceSession, MobilePendingChallenge,
)
from .session_store import (
    issue_verified_candidate_session,
)

_RECOVERY_DOMAIN = b"vencira:native:account-recovery:challenge:v1:"


def _recovery_digest(login_digest):
    return hashlib.sha256(
        _RECOVERY_DOMAIN + bytes.fromhex(login_digest)
    ).hexdigest()


def _matches_recovery(wire, row):
    # Never allow ordinary login challenge to be used for account recovery.
    try:
        challenge_id, raw = parse_candidate_challenge(wire)
    except NativeChallengeMalformed:
        return False
    if challenge_id != row.pk:
        return False
    # The regular canonical digest is recomputed locally for the *same*
    # challenge material, then domain-separated for recovery custody.
    digest = hashlib.sha256(
        b"vencira:mobile:challenge:v1:" + challenge_id.bytes + raw
    ).hexdigest()
    return hmac.compare_digest(_recovery_digest(digest), row.secret_digest)


def recovery_password_to_challenge(*, username, password, request_meta,
                                   event_id, ttl_seconds=300):
    """After password admission, issue a recovery-only MFA challenge."""
    _require_lab()
    if (type(username) is not str or not username or
            username != username.strip() or len(username) > 150 or
            type(password) is not str or not password or len(password) > 4096 or
            type(event_id) is not uuid.UUID or
            type(ttl_seconds) is not int or not 1 <= ttl_seconds <= 300):
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
            id=challenge_id, user=user,
            secret_digest=_recovery_digest(digest),
            credential_version=mobile_credential_version(user),
            mfa_epoch=state.session_epoch,
            auth_generation=_generation(user.pk),
            expires_at=timezone.now() + timedelta(seconds=ttl_seconds),
        )
        return wire


def recovery_mfa_to_atomic_session(*, wire, code, keys, event_id,
                                   timestamp=None):
    """One PG17 commit: fresh TOTP -> revoke ALL old sessions -> new one.

    Ordering: account/user -> MFA state -> challenge -> generation/devices.
    Audit failure aborts revocation, TOTP consumption and new token insertion.
    """
    _require_lab()
    if (type(event_id) is not uuid.UUID or type(code) is not str or
            len(code) != 6 or not code.isascii() or not code.isdecimal() or
            type(keys) is not list or not keys):
        raise CandidateChallengeDenied()
    try:
        challenge_id, _ = parse_candidate_challenge(wire)
    except NativeChallengeMalformed:
        raise CandidateChallengeDenied() from None
    with transaction.atomic():
        user_id = MobilePendingChallenge.objects.filter(
            pk=challenge_id,
        ).values_list("user_id", flat=True).first()
        if user_id is None:
            raise CandidateChallengeDenied()
        user = get_user_model().objects.select_for_update().filter(
            pk=user_id, is_active=True,
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
                or not _matches_recovery(wire, row)):
            raise CandidateChallengeDenied()
        if not consume_totp(user.pk, code, keys=keys, timestamp=timestamp):
            record_candidate_auth_event(
                event_id=event_id, event_type="auth_denied",
                actor=user.username,
            )
            return None
        # No new access before the old devices have been invalidated in
        # this same database transaction.
        fence, _ = MobileAccountFence.objects.get_or_create(
            user_id=user.pk, defaults={"generation": 0},
        )
        MobileAccountFence.objects.filter(pk=user.pk).update(
            generation=F("generation") + 1,
        )
        fence.refresh_from_db(fields=["generation"])
        MobileDeviceSession.objects.filter(
            user_id=user.pk, revoked_at__isnull=True,
        ).update(
            revoked_at=now, access_digest="", refresh_digest="",
        )
        row.consumed_at = now
        row.save(update_fields=["consumed_at"])
        pair = issue_verified_candidate_session(
            user_id=user.pk, verified_mfa=True,
            mfa_epoch=state.session_epoch,
            expected_generation=fence.generation,
        )
        # Both event rows MUST succeed. Never expose credentials if
        # audit custody fails, even after the old devices are updated.
        _, created = record_candidate_auth_event(
            event_id=uuid.uuid5(event_id, "account_revoke"),
            event_type="account_revoke", actor=user.username,
        )
        _, authenticated = record_candidate_auth_event(
            event_id=event_id, event_type="auth_verified",
            actor=user.username,
        )
        if not (created and authenticated):
            raise CandidateChallengeDenied()
        return pair
