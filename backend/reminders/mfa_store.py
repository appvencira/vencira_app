"""D1.5c: consumo transaccional; NO integra ni habilita el login MFA."""
import hmac

from django.db import transaction

from .mfa_secrets import verify_recovery_code
from .mfa_totp import match_counter
from .models import UserMfaRecoveryCode, UserMfaState


@transaction.atomic
def consume_totp(user_id: int, code: str, *, keys: list[str], timestamp: int | None = None) -> bool:
    from .mfa_secrets import decrypt_totp_secret
    state = UserMfaState.objects.select_for_update().filter(user_id=user_id, enabled=True).first()
    if state is None:
        return False
    secret = decrypt_totp_secret(state.encrypted_totp_secret, user_id=user_id, keys=keys)
    counter = match_counter(
        secret, code, timestamp=timestamp,
        last_accepted_counter=state.last_accepted_counter,
    )
    if counter is None:
        return False
    state.last_accepted_counter = counter
    state.save(update_fields=["last_accepted_counter", "updated_at"])
    return True


@transaction.atomic
def consume_recovery_code(user_id: int, code: str) -> bool:
    if not isinstance(code, str) or len(code) != 32 or not code.isascii():
        return False
    state = UserMfaState.objects.select_for_update().filter(user_id=user_id, enabled=True).first()
    if state is None:
        return False
    for candidate in UserMfaRecoveryCode.objects.filter(state=state).order_by("pk"):
        if verify_recovery_code(code, candidate.code_hash):
            candidate.delete()
            return True
    return False
