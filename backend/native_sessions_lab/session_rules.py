"""Test-only device-session state transitions; no HTTP or production imports."""
from datetime import timedelta
from django.db import transaction
from django.utils import timezone
from reminders.native_mobile_identity_gate import (
    require_mobile_identity_gate, mobile_credential_version, MobileIdentityDenied,
)
from reminders.native_mobile_token_primitives import (
    make_native_token, native_token_digest, parse_native_token,
    matches_native_token, NativeMobileTokenInvalid,
)
from .models import MobileDeviceSessionLab, SpentRefreshLab

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


def issue_verified_session(*, user, verified_mfa, mfa_epoch):
    """Input assertion MUST originate from a verified factor (lab has no login)."""
    version = mobile_credential_version(user)
    _identity(user, verified_mfa, mfa_epoch, version)
    now = timezone.now()
    with transaction.atomic():
        row = MobileDeviceSessionLab(
            user=user, credential_version=version,
            verified_mfa=verified_mfa, mfa_epoch=mfa_epoch,
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
    return _identity(
        row.user, row.verified_mfa, row.mfa_epoch, row.credential_version)
