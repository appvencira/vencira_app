"""Test-only device-session state transitions; no HTTP or production imports."""
from datetime import timedelta
from django.db import transaction
from django.contrib.auth import get_user_model
from django.db.models import F
from django.utils import timezone
from reminders.native_mobile_identity_gate import (
    require_mobile_identity_gate, mobile_credential_version, MobileIdentityDenied,
)
from reminders.native_mobile_token_primitives import (
    make_native_token, native_token_digest, parse_native_token,
    matches_native_token, NativeMobileTokenInvalid,
)
from .models import (MobileAccountFenceLab, MobileDeviceSessionLab,
                     MobileLoginChallengeLab, SpentRefreshLab)

ACCESS_AGE = timedelta(minutes=5)
REFRESH_AGE = timedelta(days=30)


class SessionLabDenied(Exception):
    """Generic failure; never return details to a hypothetical client."""


def _identity(user, verified_mfa, mfa_epoch, credential_version):
    try:
        return require_mobile_identity_gate(
            user=user, verified_mfa=verified_mfa,
            asserted_mfa_epoch=mfa_epoch,
            asserted_credential_version=credential_version,
        )
    except MobileIdentityDenied as exc:
        raise SessionLabDenied() from exc


def account_generation_lab(user_id):
    """Current account epoch; absent row is generation 0 (lab schema only)."""
    row = MobileAccountFenceLab.objects.filter(user_id=user_id).first()
    return row.generation if row is not None else 0


def lock_account_lab(user_id):
    """Shared serialisation point for login issuance and mass revocation."""
    user = get_user_model().objects.select_for_update().filter(pk=user_id).first()
    if user is None:
        raise SessionLabDenied()
    return user


def _find(token, kind, *, lock=False):
    try:
        session_id = parse_native_token(token, kind=kind)
    except NativeMobileTokenInvalid as exc:
        raise SessionLabDenied() from exc
    qs = MobileDeviceSessionLab.objects
    if lock:
        qs = qs.select_for_update()
    row = qs.filter(pk=session_id).first()
    if row is None:
        raise SessionLabDenied()
    return row


def issue_verified_session(
    *, user, verified_mfa, mfa_epoch, expected_generation,
):
    """Lab-only: caller already established password and MFA trust.

    Each session is created behind the same per-account DB row lock as
    revocation; a stale pre-revoke login is rejected by expected_generation.
    """
    if user is None or type(getattr(user, "pk", None)) is not int:
        raise SessionLabDenied()
    with transaction.atomic():
        current_user = lock_account_lab(user.pk)
        generation = account_generation_lab(current_user.pk)
        if (type(expected_generation) is not int
                or expected_generation != generation):
            raise SessionLabDenied()
        version = mobile_credential_version(current_user)
        _identity(current_user, verified_mfa, mfa_epoch, version)
        now = timezone.now()
        row = MobileDeviceSessionLab(
            user=current_user, credential_version=version,
            verified_mfa=verified_mfa, mfa_epoch=mfa_epoch,
            auth_generation=generation,
            access_expires_at=now + ACCESS_AGE,
            refresh_expires_at=now + REFRESH_AGE,
            access_digest="", refresh_digest="",
        )
        access = make_native_token(kind="a", session_id=row.pk)
        refresh = make_native_token(kind="r", session_id=row.pk)
        row.access_digest = native_token_digest(access, kind="a")
        row.refresh_digest = native_token_digest(refresh, kind="r")
        row.save(force_insert=True)
    return access, refresh

def validate_access(token):
    row = _find(token, "a")
    now = timezone.now()
    if (row.revoked_at is not None or row.access_expires_at <= now
            or row.refresh_expires_at <= now
            or not matches_native_token(
                token, kind="a", stored_digest=row.access_digest)):
        raise SessionLabDenied()
    if row.auth_generation != account_generation_lab(row.user_id):
        raise SessionLabDenied()
    return _identity(
        row.user, row.verified_mfa, row.mfa_epoch, row.credential_version)


def rotate_refresh(token):
    """Lock, rotate once and revoke on replay of a PREVIOUS valid token.

    The revocation is committed before raising on replay; unknown tokens
    must not be allowed to revoke another user's session.
    """
    revoked_for_replay = False
    result = None
    with transaction.atomic():
        row = _find(token, "r", lock=True)
        # A request may wait for a PG17 row lock. Evaluate expiry AFTER
        # acquiring that lock, never before entering the wait.
        now = timezone.now()
        if row.revoked_at is not None or row.refresh_expires_at <= now:
            raise SessionLabDenied()
        digest = native_token_digest(token, kind="r")
        if not matches_native_token(
                token, kind="r", stored_digest=row.refresh_digest):
            if not SpentRefreshLab.objects.filter(
                    session=row, digest=digest).exists():
                raise SessionLabDenied()
            row.revoked_at = now
            row.access_digest = ""
            row.refresh_digest = ""
            row.save(update_fields=[
                "revoked_at", "access_digest", "refresh_digest",
            ])
            revoked_for_replay = True
        else:
            if row.auth_generation != account_generation_lab(row.user_id):
                raise SessionLabDenied()
            _identity(
                row.user, row.verified_mfa, row.mfa_epoch,
                row.credential_version,
            )
            SpentRefreshLab.objects.create(
                session=row, digest=row.refresh_digest)
            access = make_native_token(kind="a", session_id=row.pk)
            refresh = make_native_token(kind="r", session_id=row.pk)
            row.access_digest = native_token_digest(access, kind="a")
            row.refresh_digest = native_token_digest(refresh, kind="r")
            row.access_expires_at = min(
                now + ACCESS_AGE, row.refresh_expires_at)
            row.generation += 1
            row.save(update_fields=[
                "access_digest", "refresh_digest", "access_expires_at",
                "generation",
            ])
            result = (access, refresh)
    if revoked_for_replay:
        raise SessionLabDenied()
    return result


def revoke_device(refresh_token):
    """Current refresh-token holder can revoke only its own device."""
    with transaction.atomic():
        row = _find(refresh_token, "r", lock=True)
        if (row.revoked_at is not None or not matches_native_token(
                refresh_token, kind="r",
                stored_digest=row.refresh_digest)):
            raise SessionLabDenied()
        row.revoked_at = timezone.now()
        row.access_digest = ""
        row.refresh_digest = ""
        row.save(update_fields=[
            "revoked_at", "access_digest", "refresh_digest",
        ])


def revoke_all_devices_for_user_lab(*, user_id):
    """Lab-only privileged operation. Caller authorisation is NOT implemented.

    One per-user lock serializes challenge/issuer/revoke writes. Increment
    the epoch even with zero devices and permanently consume old challenges.
    A later independently authenticated login may still create new sessions:
    this is NOT an account lockout or stolen-password remediation.
    """
    if type(user_id) is not int or user_id <= 0:
        raise SessionLabDenied()
    with transaction.atomic():
        lock_account_lab(user_id)
        MobileAccountFenceLab.objects.get_or_create(
            user_id=user_id, defaults={"generation": 0},
        )
        MobileAccountFenceLab.objects.filter(user_id=user_id).update(
            generation=F("generation") + 1,
        )
        now = timezone.now()
        MobileLoginChallengeLab.objects.filter(
            user_id=user_id, consumed_at__isnull=True,
        ).update(consumed_at=now)
        rows = list(
            MobileDeviceSessionLab.objects.select_for_update()
            .filter(user_id=user_id, revoked_at__isnull=True)
            .order_by("pk")
        )
        if not rows:
            return 0
        count = MobileDeviceSessionLab.objects.filter(
            pk__in=[row.pk for row in rows],
            revoked_at__isnull=True,
        ).update(
            revoked_at=now,
            access_digest="",
            refresh_digest="",
        )
        return count
