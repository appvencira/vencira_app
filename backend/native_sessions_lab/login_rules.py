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
from .session_rules import (
    SessionLabDenied, issue_verified_session, account_generation_lab,
    lock_account_lab, revoke_all_devices_for_user_lab,
)

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


def begin_native_login_lab(username, password, *, replace_devices=False):
    """Lab only: password then optional MFA challenge (no public HTTP)."""
    if (type(username) is not str or not 1 <= len(username) <= 150
            or type(password) is not str or not password
            or type(replace_devices) is not bool):
        raise NativeLoginLabDenied()
    try:
        if is_blocked(username):
            raise NativeLoginLabDenied()
        user = authenticate(username=username, password=password)
        if user is None or not user.is_active:
            register_failure(username)
            raise NativeLoginLabDenied()

        # Capture the epoch before acquiring the account lock. A concurrent
        # revocation invalidates this login attempt rather than silently
        # issuing tokens from an old password/MFA challenge.
        initial_generation = account_generation_lab(user.pk)
        with transaction.atomic():
            current_user = lock_account_lab(user.pk)
            if account_generation_lab(current_user.pk) != initial_generation:
                raise NativeLoginLabDenied()
            version = mobile_credential_version(current_user)
            state = UserMfaState.objects.filter(user_id=current_user.pk).first()
            if state is None or not state.enabled:
                # The password is already verified. The identity predicate
                # independently denies MFA recovery quarantine before revoke.
                if replace_devices:
                    require_mobile_identity_gate(
                        user=current_user, verified_mfa=False,
                        asserted_mfa_epoch=None,
                        asserted_credential_version=version,
                    )
                    revoke_all_devices_for_user_lab(user_id=current_user.pk)
                    initial_generation = account_generation_lab(current_user.pk)
                issued = issue_verified_session(
                    user=current_user, verified_mfa=False, mfa_epoch=None,
                    expected_generation=initial_generation,
                )
                mode, result = "ready", issued
            else:
                # No bearer issued until TOTP is consumed and state rechecked.
                require_mobile_identity_gate(
                    user=current_user, verified_mfa=True,
                    asserted_mfa_epoch=state.session_epoch,
                    asserted_credential_version=version,
                )
                sid = uuid.uuid4()
                secret = base64.urlsafe_b64encode(
                    secrets.token_bytes(32),
                ).decode("ascii").rstrip("=")
                raw = f"lc1.{sid.hex}.{secret}"
                MobileLoginChallengeLab.objects.create(
                    id=sid, user=current_user,
                    secret_digest=_digest(raw),
                    credential_version=version,
                    mfa_epoch=state.session_epoch,
                    auth_generation=initial_generation,
                    replace_devices=replace_devices,
                    expires_at=timezone.now() + CHALLENGE_AGE,
                )
                mode, result = "mfa", raw
        if mode == "ready":
            clear_failures(username)
        return mode, result
    except (SessionLabDenied, MobileIdentityDenied) as exc:
        raise NativeLoginLabDenied() from exc


def finish_native_mfa_lab(challenge, code, *, expected_recovery=False):
    """Lab-only MFA completion: lock user BEFORE challenge to avoid deadlock.

    Account-wide revocation takes the same user lock and increments its
    generation, so pending/competing challenges cannot resurrect sessions.
    """
    sid = _challenge_id(challenge)
    if (type(code) is not str or len(code) > 256
            or type(expected_recovery) is not bool):
        raise NativeLoginLabDenied()
    accepted = False
    credentials = None
    try:
        with transaction.atomic():
            # The first read is ONLY a locator; do not trust it as authority.
            user_id = MobileLoginChallengeLab.objects.filter(
                pk=sid,
            ).values_list("user_id", flat=True).first()
            if user_id is None:
                raise NativeLoginLabDenied()
            user = lock_account_lab(user_id)
            record = MobileLoginChallengeLab.objects.select_for_update().filter(
                pk=sid, user_id=user.pk,
            ).first()
            if (record is None
                    or record.replace_devices is not expected_recovery
                    or record.consumed_at is not None
                    or record.expires_at <= timezone.now()
                    or record.auth_generation != account_generation_lab(user.pk)
                    or not constant_time_compare(
                        _digest(challenge), record.secret_digest,
                    )):
                raise NativeLoginLabDenied()
            require_mobile_identity_gate(
                user=user, verified_mfa=True,
                asserted_mfa_epoch=record.mfa_epoch,
                asserted_credential_version=record.credential_version,
            )
            keys = load_mfa_keys()
            accepted = consume_totp(user.pk, code, keys=keys)
            if accepted:
                expected_generation = record.auth_generation
                if expected_recovery:
                    # Only a completed second factor may revoke other devices.
                    # Same user row lock serializes revocation and issuance.
                    revoke_all_devices_for_user_lab(user_id=user.pk)
                    expected_generation = account_generation_lab(user.pk)
                credentials = issue_verified_session(
                    user=user, verified_mfa=True,
                    mfa_epoch=record.mfa_epoch,
                    expected_generation=expected_generation,
                )
                record.consumed_at = timezone.now()
                record.save(update_fields=["consumed_at"])
                clear_failures(user.get_username())
        # Deny AFTER commit; a failed OTP must increment the MFA counter.
        if not accepted:
            raise NativeLoginLabDenied()
        return credentials
    except (SessionLabDenied, MobileIdentityDenied, ValueError) as exc:
        raise NativeLoginLabDenied() from exc
