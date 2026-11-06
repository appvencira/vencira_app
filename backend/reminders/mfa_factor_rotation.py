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
from .mfa_totp import generate_secret, match_counter
from .models import UserMfaState, UserMfaRecoveryCode, UserMfaPendingRotationCode
from .mfa_store import _failed, _succeeded
from .models import MfaAdministrativeRecoveryCase

ROTATION_TTL = timedelta(minutes=10)


def recovery_pending(user_id):
    return MfaAdministrativeRecoveryCase.objects.filter(
        subject_id=user_id, status=MfaAdministrativeRecoveryCase.Status.PENDING,
    ).exists()


@transaction.atomic
def prepare_factor_rotation(*, user_id, old_code, keys, timestamp=None):
    """Requiere código del TOTP activo; devuelve secreto nuevo solo al servicio."""
    state = UserMfaState.objects.select_for_update().get(user_id=user_id)
    if not state.enabled or recovery_pending(user_id) or state.pending_administrative_case_id:
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
    UserMfaPendingRotationCode.objects.filter(state=state).delete()
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
    if (recovery_pending(user_id) or state.pending_administrative_case_id or not state.enabled or not state.pending_rotation_secret
            or state.pending_rotation_expires_at is None
            or now >= state.pending_rotation_expires_at
            or (state.locked_until and state.locked_until > now)):
        return None
    new_secret = decrypt_totp_secret(
        state.pending_rotation_secret, user_id=user_id, keys=keys,
    )
    counter = match_counter(new_secret, new_code, timestamp=timestamp)
    if counter is None:
        _failed(state, now)
        return None
    # Se emiten códigos provisionales; ni el factor ni los códigos activos
    # cambian hasta acreditar posesión de uno de los nuevos.
    if UserMfaPendingRotationCode.objects.filter(state=state).exists():
        return None
    _succeeded(state)
    codes = generate_recovery_codes()
    UserMfaPendingRotationCode.objects.bulk_create([
        UserMfaPendingRotationCode(state=state, code_hash=hash_recovery_code(value))
        for value in codes
    ])
    return codes


@transaction.atomic
def finalize_factor_rotation(*, user_id, proof_code, keys, timestamp=None):
    """Activa el factor pendiente solo después del acuse del código provisional.

    Si la entrega anterior se pierde, TOTP y códigos anteriores siguen
    operativos. Esta primitiva es interna y NO se expone como endpoint.
    """
    from .mfa_secrets import verify_recovery_code
    state = UserMfaState.objects.select_for_update().get(user_id=user_id)
    now = timezone.now()
    if (recovery_pending(user_id) or state.pending_administrative_case_id or not state.enabled or not state.pending_rotation_secret
            or state.pending_rotation_expires_at is None
            or now >= state.pending_rotation_expires_at
            or (state.locked_until and state.locked_until > now)):
        return False
    pending = list(UserMfaPendingRotationCode.objects.filter(state=state))
    if len(pending) != 10:
        return False
    if not isinstance(proof_code, str) or len(proof_code) != 32 or not any(
        verify_recovery_code(proof_code, item.code_hash) for item in pending
    ):
        _failed(state, now)
        return False
    # TOTP pendiente fue acreditado en confirm_factor_rotation.
    UserMfaRecoveryCode.objects.filter(state=state).delete()
    UserMfaRecoveryCode.objects.bulk_create([
        UserMfaRecoveryCode(state=state, code_hash=item.code_hash) for item in pending
    ])
    UserMfaPendingRotationCode.objects.filter(state=state).delete()
    state.encrypted_totp_secret = state.pending_rotation_secret
    state.pending_rotation_secret = ""
    state.pending_rotation_expires_at = None
    state.last_accepted_counter = -1
    state.session_epoch += 1
    state.save(update_fields=[
        "encrypted_totp_secret", "pending_rotation_secret",
        "pending_rotation_expires_at", "last_accepted_counter",
        "session_epoch", "updated_at",
    ])
    return True
