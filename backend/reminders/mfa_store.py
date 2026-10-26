"""D1.5d: consumo MFA transaccional con límite de intentos por cuenta.

No está conectado a login; nunca pasar secretos ni códigos a logs.
"""
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .mfa_secrets import decrypt_totp_secret, verify_recovery_code
from .mfa_totp import match_counter
from .models import UserMfaRecoveryCode, UserMfaState

MAX_FAILURES = 5
FAILURE_WINDOW = timedelta(minutes=15)
LOCK_DURATION = timedelta(minutes=15)


def _blocked(state, now):
    return bool(state.locked_until and state.locked_until > now)


def _failed(state, now):
    if state.attempts_started_at is None or now - state.attempts_started_at >= FAILURE_WINDOW:
        state.attempts_started_at = now
        state.failed_attempts = 0
    state.failed_attempts += 1
    if state.failed_attempts >= MAX_FAILURES:
        state.locked_until = now + LOCK_DURATION
    state.save(update_fields=[
        "attempts_started_at", "failed_attempts", "locked_until", "updated_at",
    ])


def _succeeded(state):
    state.failed_attempts = 0
    state.attempts_started_at = None
    state.locked_until = None
    state.save(update_fields=[
        "failed_attempts", "attempts_started_at", "locked_until", "updated_at",
    ])


@transaction.atomic
def consume_totp(user_id: int, code: str, *, keys: list[str], timestamp: int | None = None) -> bool:
    state = UserMfaState.objects.select_for_update().filter(user_id=user_id, enabled=True).first()
    if state is None:
        return False
    now = timezone.now()
    if _blocked(state, now):
        return False
    secret = decrypt_totp_secret(state.encrypted_totp_secret, user_id=user_id, keys=keys)
    counter = match_counter(
        secret, code, timestamp=timestamp,
        last_accepted_counter=state.last_accepted_counter,
    )
    if counter is None:
        _failed(state, now)
        return False
    state.last_accepted_counter = counter
    state.save(update_fields=["last_accepted_counter", "updated_at"])
    _succeeded(state)
    return True


@transaction.atomic
def consume_recovery_code(user_id: int, code: str) -> bool:
    state = UserMfaState.objects.select_for_update().filter(user_id=user_id, enabled=True).first()
    if state is None:
        return False
    now = timezone.now()
    if _blocked(state, now):
        return False
    if isinstance(code, str) and len(code) == 32 and code.isascii():
        for candidate in UserMfaRecoveryCode.objects.filter(state=state).order_by("pk"):
            if verify_recovery_code(code, candidate.code_hash):
                candidate.delete()
                _succeeded(state)
                return True
    _failed(state, now)
    return False
