"""D1.5e: preparación y confirmación MFA exclusivamente como servicio interno.

NO exponer endpoints de enrolamiento hasta que el login imponga el segundo
factor: habilitar MFA antes permitiría seguir autenticándose solo con contraseña.
La clave de cifrado debe venir de un almacén externo, nunca de SECRET_KEY.
"""
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .mfa_secrets import (
    decrypt_totp_secret, encrypt_totp_secret,
    generate_recovery_codes, hash_recovery_code,
)
from .mfa_totp import generate_secret, match_counter, provisioning_uri
from .models import UserMfaRecoveryCode, UserMfaState

PENDING_LIFETIME = timedelta(minutes=10)


@transaction.atomic
def prepare_mfa(user, *, keys: list[str]) -> tuple[str, str]:
    """Devuelve clave Base32 y URI SOLO al titular tras reautenticación externa.

    Es una primitiva interna; la capa HTTP futura debe exigir contraseña
    reciente, CSRF, control de intentos y no cachear la respuesta.
    """
    state, _ = UserMfaState.objects.select_for_update().get_or_create(
        user=user, defaults={"encrypted_totp_secret": ""},
    )
    if state.enabled:
        raise ValueError("MFA ya está activo")
    secret = generate_secret()
    state.encrypted_totp_secret = encrypt_totp_secret(secret, user_id=user.pk, keys=keys)
    state.last_accepted_counter = -1
    state.failed_attempts = 0
    state.attempts_started_at = None
    state.locked_until = None
    state.save()
    UserMfaRecoveryCode.objects.filter(state=state).delete()
    return secret, provisioning_uri(secret, user.get_username())


@transaction.atomic
def confirm_mfa(user_id: int, code: str, *, keys: list[str],
                timestamp: int | None = None) -> list[str] | None:
    """Habilita MFA al confirmar TOTP y genera recuperación, solo en un flujo
    que ya haya garantizado el enforcement MFA en LOGIN (D1.5f). No llamar
    desde API/producción antes de ese gate.
    """
    state = UserMfaState.objects.select_for_update().filter(
        user_id=user_id, enabled=False,
    ).first()
    if state is None or not state.encrypted_totp_secret:
        return None
    now = timezone.now()
    if now - state.updated_at > PENDING_LIFETIME:
        return None
    if state.locked_until and state.locked_until > now:
        return None
    secret = decrypt_totp_secret(
        state.encrypted_totp_secret, user_id=user_id, keys=keys,
    )
    counter = match_counter(secret, code, timestamp=timestamp, window=1)
    if counter is None:
        from .mfa_store import _failed
        _failed(state, now)
        return None
    codes = generate_recovery_codes()
    UserMfaRecoveryCode.objects.bulk_create([
        UserMfaRecoveryCode(state=state, code_hash=hash_recovery_code(value))
        for value in codes
    ])
    state.last_accepted_counter = counter
    state.enabled = True
    state.failed_attempts = 0
    state.attempts_started_at = None
    state.locked_until = None
    state.save()
    return codes
