"""D1.5h: validación sin efectos secundarios del anillo de claves MFA.

La primera clave cifra nuevos secretos; las restantes solo descifran durante
rotación. Nunca registrar valores de claves ni usar DJANGO_SECRET_KEY.
"""
import os

from cryptography.fernet import Fernet


def load_mfa_keys(*, environ=None) -> list[str]:
    env = os.environ if environ is None else environ
    raw = env.get("VENCIRA_MFA_FERNET_KEYS", "")
    if not isinstance(raw, str) or not raw.strip():
        raise ValueError("Claves MFA no configuradas")
    keys = [part.strip() for part in raw.split(",")]
    if not keys or any(not key for key in keys):
        raise ValueError("Anillo de claves MFA inválido")
    if len(keys) > 5 or len(set(keys)) != len(keys):
        raise ValueError("Anillo de claves MFA inválido")
    try:
        for key in keys:
            Fernet(key.encode("ascii"))
    except (ValueError, UnicodeError, TypeError) as exc:
        raise ValueError("Clave MFA inválida") from exc
    return keys
