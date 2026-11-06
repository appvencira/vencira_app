"""D1.5b: primitivas aisladas de secretos MFA; NO activan autenticación.

La lista de claves debe venir de un almacén independiente de DJANGO_SECRET_KEY.
Primera clave cifra; claves antiguas descifran durante rotación controlada.
El resultado cifrado exige un contexto (usuario) mediante AEAD asociado por
Fernet no configurable, así que usamos derivación por cuenta en la entrada
para evitar trasplantes accidentales de secreto entre cuentas.
"""
import base64
import hashlib
import hmac
import secrets

from cryptography.fernet import Fernet, InvalidToken, MultiFernet
from django.contrib.auth.hashers import check_password, make_password

RECOVERY_COUNT = 10
RECOVERY_BYTES = 20
PREFIX = "v1:"


def _keyring(keys: list[str]) -> MultiFernet:
    if not isinstance(keys, list) or not keys:
        raise ValueError("Se necesita una clave MFA independiente")
    try:
        return MultiFernet([Fernet(key.encode("ascii")) for key in keys])
    except (ValueError, TypeError, AttributeError) as exc:
        raise ValueError("Clave MFA inválida") from exc


def encrypt_totp_secret(secret: str, *, user_id: int, keys: list[str]) -> str:
    if not isinstance(secret, str) or not secret or user_id <= 0:
        raise ValueError("Dato MFA inválido")
    plaintext = f"{user_id}:{secret}".encode("utf-8")
    return PREFIX + _keyring(keys).encrypt(plaintext).decode("ascii")


def decrypt_totp_secret(token: str, *, user_id: int, keys: list[str]) -> str:
    if not isinstance(token, str) or not token.startswith(PREFIX) or user_id <= 0:
        raise ValueError("Dato MFA cifrado inválido")
    try:
        plaintext = _keyring(keys).decrypt(token[len(PREFIX):].encode("ascii"))
        account, secret = plaintext.decode("utf-8").split(":", 1)
        if not hmac.compare_digest(account, str(user_id)) or not secret:
            raise ValueError("Secreto no pertenece a esta cuenta")
        return secret
    except (InvalidToken, UnicodeError, ValueError) as exc:
        raise ValueError("No se puede descifrar el secreto MFA") from exc


def rotate_totp_secret(token: str, *, user_id: int,
                       old_keys: list[str], new_keys: list[str]) -> str:
    secret = decrypt_totp_secret(token, user_id=user_id, keys=old_keys)
    return encrypt_totp_secret(secret, user_id=user_id, keys=new_keys)


def generate_recovery_codes() -> list[str]:
    # 160 bits por código; formato estable, legible y sin ambigüedades.
    return [base64.b32encode(secrets.token_bytes(RECOVERY_BYTES))
            .decode("ascii").rstrip("=") for _ in range(RECOVERY_COUNT)]


def hash_recovery_code(code: str) -> str:
    if not isinstance(code, str) or len(code) != 32 or any(
        c not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" for c in code
    ):
        raise ValueError("Código de recuperación inválido")
    return make_password(code, hasher="pbkdf2_sha256")


def verify_recovery_code(code: str, encoded: str) -> bool:
    if not isinstance(code, str) or len(code) != 32 or not code.isascii():
        return False
    return check_password(code, encoded) if isinstance(encoded, str) else False
