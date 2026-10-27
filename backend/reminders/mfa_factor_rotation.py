"""Cambio de TOTP con factor anterior vigente, sin bypass de recuperación.

Solo primitivas internas. El nuevo factor se prepara separado del activo y
se activa atómicamente tras acreditar posesión del factor anterior y del nuevo.
La recuperación administrativa SIN factor anterior requiere otro protocolo.
"""
from datetime import timedelta
from django.db import transaction
from django.utils import timezone

from .mfa_secrets import (
    decrypt_totp_secret, encrypt_totp_secret, generate_recovery_codes,
    hash_recovery_code,
)
from .mfa_totp import generate_secret, match_counter, provisioning_uri
from .models import UserMfaState, UserMfaRecoveryCode
from .mfa_store import _failed, _succeeded

ROTATION_TTL = timedelta(minutes=10)


@transaction.atomic
def prepare_factor_rotation(*, user_id, old_code, keys, timestamp=None):
    """Requiere código del TOTP activo; devuelve secreto nuevo solo al servicio."""
    state = UserMfaState.objects.select_for_update().get(user_id=user_id)
    if not state.enabled:
        return None
    now = timezone.now()
    if state.locked_until and state.locked_until > now:
        return None
    old_secret = decrypt_totp_secret(
        state.encrypted_totp_secret, user_id=user_id, keys=keys,
    )
    counter = match_counter(old_secret, old_code, timestamp=timestamp,
                            last_accepted_counter=state.last_accepted_counter)
    if counter is None:
        _failed(state, now)
        return None
    _succeeded(state)
    new_secret = generate_secret()
    state.last_accepted_counter = counter
    state.pending_rotation_secret = encrypt_totp_secret(
        new_secret, user_id=user_id, keys=keys,
    )
    state.pending_rotation_expires_at = now + ROTATION_TTL
    state.save(update_fields=[
        "last_accepted_counter", "pending_rotation_secret",
        "pending_rotation_expires_at", "updated_at",
    ])
    return new_secret


@transaction.atomic
def confirm_factor_rotation(*, user_id, new_code, keys, timestamp=None):
    """Cambiar TOTP y códigos en la misma transacción, revocando sesiones.

    Solo normal rotation con prueba del factor antiguo. No exponer por API hasta
    incorporar reautenticación, CSRF, límites e identidad de sesión.
    """
    state = UserMfaState.objects.select_for_update().get(user_id=user_id)
    now = timezone.now()
    if (not state.enabled or not state.pending_rotation_secret
            or state.pending_rotation_expires_at is None
            or now >= state.pending_rotation_expires_at):
        return None
    new_secret = decrypt_totp_secret(
        state.pending_rotation_secret, user_id=user_id, keys=keys,
    )
    counter = match_counter(new_secret, new_code, timestamp=timestamp)
    if state.locked_until and state.locked_until > now:
        return None
    if counter is None:
        _failed(state, now)
        return None
    _succeeded(state)
    codes = generate_recovery_codes()
    hashes = [hash_recovery_code(code) for code in codes]
    UserMfaRecoveryCode.objects.filter(state=state).delete()
    UserMfaRecoveryCode.objects.bulk_create([
        UserMfaRecoveryCode(state=state, code_hash=value) for value in hashes
    ])
    state.encrypted_totp_secret = state.pending_rotation_secret
    state.pending_rotation_secret = ""
    state.pending_rotation_expires_at = None
    state.last_accepted_counter = counter
    state.session_epoch += 1
    state.save(update_fields=[
        "encrypted_totp_secret", "pending_rotation_secret",
        "pending_rotation_expires_at", "last_accepted_counter",
        "session_epoch", "updated_at",
    ])
    return codes
