"""G4 operational-shaped opaque-token store; isolated candidate only.

No HTTP login, trusted issuer, public endpoint, or release authorization exists.
The issue_verified_candidate_session entrypoint is deliberately test gated.
"""
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import F
from django.utils import timezone

from reminders.native_mobile_identity_gate import (
    MobileIdentityDenied, mobile_credential_version, require_mobile_identity_gate,
)
from reminders.native_mobile_token_primitives import (
    NativeMobileTokenInvalid, make_native_token, matches_native_token,
    native_token_digest, parse_native_token,
)

from .models import MobileAccountFence, MobileDeviceSession, MobileSpentRefresh

ACCESS_AGE = timedelta(minutes=5)
REFRESH_AGE = timedelta(days=30)


class MobileTokenDenied(Exception):
    """Never reveal whether a device, account, or MFA state exists."""


def _gate():
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and "native_mobile_service" in settings.INSTALLED_APPS
    ):
        raise MobileTokenDenied()


def _identity(row):
    try:
        return require_mobile_identity_gate(
            user=row.user,
            verified_mfa=row.verified_mfa,
            asserted_mfa_epoch=row.mfa_epoch,
            asserted_credential_version=row.credential_version,
        )
    except MobileIdentityDenied as exc:
        raise MobileTokenDenied() from exc


def _lock_user(user_id):
    user = get_user_model().objects.select_for_update().filter(pk=user_id).first()
    if user is None or not user.is_active:
        raise MobileTokenDenied()
    return user


def _generation(user_id):
    fence = MobileAccountFence.objects.filter(user_id=user_id).first()
    return fence.generation if fence is not None else 0


def _find(token, kind, *, lock=False):
    try:
        pk = parse_native_token(token, kind=kind)
    except NativeMobileTokenInvalid as exc:
        raise MobileTokenDenied() from exc
    rows = MobileDeviceSession.objects
    if lock:
        rows = rows.select_for_update()
    row = rows.select_related("user").filter(pk=pk).first()
    if row is None:
        raise MobileTokenDenied()
    return row


def issue_verified_candidate_session(
    *, user_id, verified_mfa, mfa_epoch, expected_generation,
):
    """Test-only boundary: a caller must have verified password and MFA.

    This method is NOT a login endpoint. It is not sufficient as a future
    production issuer because caller trust is not established here. Avoid
    importing it from operational views.
    """
    _gate()
    if type(user_id) is not int or user_id <= 0:
        raise MobileTokenDenied()
    with transaction.atomic():
        user = _lock_user(user_id)
        generation = _generation(user_id)
        if type(expected_generation) is not int or generation != expected_generation:
            raise MobileTokenDenied()
        version = mobile_credential_version(user)
        try:
            require_mobile_identity_gate(
                user=user, verified_mfa=verified_mfa,
                asserted_mfa_epoch=mfa_epoch,
                asserted_credential_version=version,
            )
        except MobileIdentityDenied as exc:
            raise MobileTokenDenied() from exc
        now = timezone.now()
        row = MobileDeviceSession(
            user=user, access_digest="", refresh_digest="",
            credential_version=version, auth_generation=generation,
            verified_mfa=verified_mfa, mfa_epoch=mfa_epoch,
            access_expires_at=now + ACCESS_AGE,
            refresh_expires_at=now + REFRESH_AGE,
        )
        access = make_native_token(kind="a", session_id=row.id)
        refresh = make_native_token(kind="r", session_id=row.id)
        row.access_digest = native_token_digest(access, kind="a")
        row.refresh_digest = native_token_digest(refresh, kind="r")
        row.save(force_insert=True)
    return access, refresh


def validate_candidate_access(token):
    _gate()
    row = _find(token, "a")
    now = timezone.now()
    if (
        row.revoked_at is not None
        or row.access_expires_at <= now
        or row.refresh_expires_at <= now
        or not matches_native_token(
            token, kind="a", stored_digest=row.access_digest
        )
        or row.auth_generation != _generation(row.user_id)
    ):
        raise MobileTokenDenied()
    return _identity(row)


def rotate_candidate_refresh(token):
    """Rotate under PG17 lock; any replay of a known spent token revokes device.

    A client MUST NOT retry an uncertain response: see G6's mandatory full
    reauthentication policy, validated separately. Revocation commits before
    raising for a replay. No refresh token is ever stored in plaintext.
    """
    _gate()
    replay = False
    result = None
    with transaction.atomic():
        row = _find(token, "r", lock=True)
        now = timezone.now()
        if row.revoked_at is not None or row.refresh_expires_at <= now:
            raise MobileTokenDenied()
        digest = native_token_digest(token, kind="r")
        if not matches_native_token(
            token, kind="r", stored_digest=row.refresh_digest
        ):
            if not MobileSpentRefresh.objects.filter(
                session=row, digest=digest,
            ).exists():
                raise MobileTokenDenied()
            row.revoked_at = now
            row.access_digest = ""
            row.refresh_digest = ""
            row.save(update_fields=[
                "revoked_at", "access_digest", "refresh_digest",
            ])
            replay = True
        else:
            if row.auth_generation != _generation(row.user_id):
                raise MobileTokenDenied()
            _identity(row)
            MobileSpentRefresh.objects.create(
                session=row, digest=row.refresh_digest,
            )
            access = make_native_token(kind="a", session_id=row.pk)
            refresh = make_native_token(kind="r", session_id=row.pk)
            row.access_digest = native_token_digest(access, kind="a")
            row.refresh_digest = native_token_digest(refresh, kind="r")
            row.access_expires_at = min(now + ACCESS_AGE, row.refresh_expires_at)
            row.rotation_generation += 1
            row.save(update_fields=[
                "access_digest", "refresh_digest", "access_expires_at",
                "rotation_generation",
            ])
            result = access, refresh
    if replay:
        raise MobileTokenDenied()
    return result


def revoke_candidate_device(token):
    _gate()
    with transaction.atomic():
        row = _find(token, "r", lock=True)
        if row.revoked_at is not None or not matches_native_token(
            token, kind="r", stored_digest=row.refresh_digest,
        ):
            raise MobileTokenDenied()
        row.revoked_at = timezone.now()
        row.access_digest = ""
        row.refresh_digest = ""
        row.save(update_fields=[
            "revoked_at", "access_digest", "refresh_digest",
        ])


def revoke_all_candidate_devices(*, user_id):
    """Test-only privileged helper; permission to invoke NOT IMPLEMENTED.

    The user lock serializes against issuance and account-wide revocation.
    NEVER expose this helper directly as an HTTP endpoint.
    """
    _gate()
    if type(user_id) is not int or user_id <= 0:
        raise MobileTokenDenied()
    with transaction.atomic():
        _lock_user(user_id)
        MobileAccountFence.objects.get_or_create(
            user_id=user_id, defaults={"generation": 0},
        )
        MobileAccountFence.objects.filter(user_id=user_id).update(
            generation=F("generation") + 1,
        )
        now = timezone.now()
        return MobileDeviceSession.objects.filter(
            user_id=user_id, revoked_at__isnull=True,
        ).update(
            revoked_at=now, access_digest="", refresh_digest="",
        )
