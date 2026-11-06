"""D1.5e: preparación y confirmación MFA exclusivamente como servicio interno.

NO exponer endpoints de enrolamiento hasta que el login imponga el segundo
factor: habilitar MFA antes permitiría seguir autenticándose solo con contraseña.
La clave de cifrado debe venir de un almacén externo, nunca de SECRET_KEY.
"""
from datetime import timedelta

from django.contrib.auth import get_user_model

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
    state.prepared_at = timezone.now()
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
    if UserMfaRecoveryCode.objects.filter(state=state).exists():
        return None
    now = timezone.now()
    if state.prepared_at is None or now - state.prepared_at > PENDING_LIFETIME:
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
    # Entrega provisional: activar solo tras demostrar posesión de un código.
    state.enabled = False
    state.failed_attempts = 0
    state.attempts_started_at = None
    state.locked_until = None
    state.save()
    return codes


@transaction.atomic
def finalize_mfa(user_id: int, proof_code: str, *, issued_at: int) -> bool:
    """Confirma custodia de un código entregado; activa solo con prueba válida.

    Una respuesta perdida no bloquea la cuenta: se puede reiniciar el alta
    mientras enabled=False y se eliminan los códigos provisionales.
    """
    from .mfa_secrets import verify_recovery_code
    from .mfa_store import _blocked, _failed
    # User -> MFA row lock order aligns with native issuance and account
    # revocation. Keep the user lock until enabled=True commits.
    if not get_user_model().objects.select_for_update().filter(
        pk=user_id, is_active=True,
    ).exists():
        return False
    state = UserMfaState.objects.select_for_update().filter(
        user_id=user_id, enabled=False,
    ).first()
    if state is None or state.prepared_at is None:
        return False
    now = timezone.now()
    if abs(now.timestamp() - issued_at) > PENDING_LIFETIME.total_seconds():
        return False
    if _blocked(state, now):
        return False
    if UserMfaRecoveryCode.objects.filter(state=state).count() != 10:
        return False
    valid = False
    if isinstance(proof_code, str) and len(proof_code) == 32:
        valid = any(
            verify_recovery_code(proof_code, stored.code_hash)
            for stored in UserMfaRecoveryCode.objects.filter(state=state).order_by("pk")
        )
    if not valid:
        _failed(state, now)
        return False
    state.enabled = True
    state.prepared_at = None
    state.failed_attempts = 0
    state.attempts_started_at = None
    state.locked_until = None
    state.save()
    return True
