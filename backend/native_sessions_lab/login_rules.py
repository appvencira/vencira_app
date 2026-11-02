"""TEST LAB ONLY: credential->MFA challenge->device-session state machine.

Not an HTTP view, production authentication module, or approved login service.
The module only belongs to native_sessions_lab (VENCIRA_ENV=test opt-in).
"""
import base64
import re
import secrets
import uuid
from datetime import timedelta

from django.contrib.auth import authenticate
from django.db import transaction
from django.utils import timezone
from django.utils.crypto import constant_time_compare, salted_hmac

from reminders.login_security import (
    clear_failures, is_blocked, register_failure,
)
from reminders.mfa_key_config import load_mfa_keys
from reminders.mfa_store import consume_totp
from reminders.models import UserMfaState
from reminders.native_mobile_identity_gate import (
    MobileIdentityDenied, mobile_credential_version,
    require_mobile_identity_gate,
)

from .models import MobileLoginChallengeLab
from .session_rules import SessionLabDenied, issue_verified_session

CHALLENGE_AGE = timedelta(minutes=5)
_CHALLENGE_FORMAT = re.compile(
    r"\Alc1\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})\Z"
)


class NativeLoginLabDenied(Exception):
    """Generic failure; never surface whether username or MFA was correct."""


def _digest(raw):
    return salted_hmac(
        "vencira.native.login-challenge.lab.v1", raw,
        algorithm="sha256",
    ).hexdigest()


def _challenge_id(raw):
    if type(raw) is not str:
        raise NativeLoginLabDenied()
    matched = _CHALLENGE_FORMAT.fullmatch(raw)
    if matched is None:
        raise NativeLoginLabDenied()
    encoded = matched.group(2)
    try:
        data = base64.urlsafe_b64decode(encoded + "=")
    except (ValueError, base64.binascii.Error) as exc:
        raise NativeLoginLabDenied() from exc
    if len(data) != 32 or base64.urlsafe_b64encode(
        data,
    ).decode("ascii").rstrip("=") != encoded:
        raise NativeLoginLabDenied()
    return uuid.UUID(hex=matched.group(1))


def begin_native_login_lab(username, password):
    """Verify Django password. Never issue tokens before enabled MFA succeeds.

    Returns ('ready', (access, refresh)) or ('mfa', challenge).
    This is NOT an endpoint and is prohibited from use outside test.
    """
    if (type(username) is not str or not 1 <= len(username) <= 150
            or type(password) is not str or not password):
        raise NativeLoginLabDenied()
    try:
        if is_blocked(username):
            raise NativeLoginLabDenied()
        user = authenticate(username=username, password=password)
        if user is None or not user.is_active:
            register_failure(username)
            raise NativeLoginLabDenied()

        version = mobile_credential_version(user)
        state = UserMfaState.objects.filter(user_id=user.pk).first()
        if state is None or not state.enabled:
            issued = issue_verified_session(
                user=user, verified_mfa=False, mfa_epoch=None)
            clear_failures(username)
            return ("ready", issued)

        # This preflight is only a DB-state check. MFA is not asserted to a
        # client, and absolutely no access/refresh token is issued here.
        require_mobile_identity_gate(
            user=user, verified_mfa=True,
            asserted_mfa_epoch=state.session_epoch,
            asserted_credential_version=version,
        )
        sid = uuid.uuid4()
        raw = base64.urlsafe_b64encode(
            secrets.token_bytes(32)).decode("ascii").rstrip("=")
        challenge = f"lc1.{sid.hex}.{raw}"
        MobileLoginChallengeLab.objects.create(
            id=sid, user=user,
            secret_digest=_digest(challenge),
            credential_version=version,
            mfa_epoch=state.session_epoch,
            expires_at=timezone.now() + CHALLENGE_AGE,
        )
        return ("mfa", challenge)
    except (SessionLabDenied, MobileIdentityDenied) as exc:
        raise NativeLoginLabDenied() from exc


def finish_native_mfa_lab(challenge, code):
    """Consume one password-bound MFA challenge and TOTP in one transaction.

    Uses existing MFA per-user row locks and replay counter. On failures,
    issue no session. All credentials and challenges are lab-only.
    """
    sid = _challenge_id(challenge)
    if type(code) is not str or len(code) > 256:
        raise NativeLoginLabDenied()
    accepted = False
    credentials = None
    try:
        with transaction.atomic():
            record = MobileLoginChallengeLab.objects.select_for_update().filter(
                pk=sid,
            ).first()
            if (record is None or record.consumed_at is not None
                    or record.expires_at <= timezone.now()
                    or not constant_time_compare(
                        _digest(challenge), record.secret_digest,
                    )):
                raise NativeLoginLabDenied()

            user = record.user
            require_mobile_identity_gate(
                user=user, verified_mfa=True,
                asserted_mfa_epoch=record.mfa_epoch,
                asserted_credential_version=record.credential_version,
            )
            keys = load_mfa_keys()
            accepted = consume_totp(user.pk, code, keys=keys)
            if accepted:
                credentials = issue_verified_session(
                    user=user, verified_mfa=True,
                    mfa_epoch=record.mfa_epoch,
                )
                record.consumed_at = timezone.now()
                record.save(update_fields=["consumed_at"])
                clear_failures(user.get_username())
        # Wrong OTP must COMMIT the rate-limit counter, even when denied.
        # Raising inside the transaction would silently roll it back.
        if not accepted:
            raise NativeLoginLabDenied()
        return credentials
    except (SessionLabDenied, MobileIdentityDenied, ValueError) as exc:
        raise NativeLoginLabDenied() from exc
