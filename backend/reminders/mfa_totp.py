"""D1.5a — Primitive TOTP RFC 6238; NO habilita MFA ni toca sesiones.

La persistencia cifrada, protección contra replay y recuperación pertenecen
a las siguientes subfases. No registrar secretos ni códigos en logs.
"""
import base64
import hashlib
import hmac
import secrets
import struct
import time
from urllib.parse import quote

STEP_SECONDS = 30
CODE_DIGITS = 6
SECRET_BYTES = 20


def generate_secret() -> str:
    """160 bits aleatorios codificados en Base32 sin padding."""
    return base64.b32encode(secrets.token_bytes(SECRET_BYTES)).decode("ascii").rstrip("=")


def _decode_secret(secret: str) -> bytes:
    if not isinstance(secret, str) or not secret:
        raise ValueError("Secreto TOTP inválido")
    normalized = secret.strip().upper()
    if any(char not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567" for char in normalized):
        raise ValueError("Secreto TOTP inválido")
    try:
        raw = base64.b32decode(normalized + "=" * (-len(normalized) % 8), casefold=False)
    except (ValueError, base64.binascii.Error) as exc:
        raise ValueError("Secreto TOTP inválido") from exc
    if len(raw) < SECRET_BYTES:
        raise ValueError("Secreto TOTP demasiado corto")
    return raw


def totp_at(secret: str, timestamp: int, *, digits: int = CODE_DIGITS) -> str:
    if digits not in (6, 8) or not isinstance(timestamp, int) or timestamp < 0:
        raise ValueError("Parámetros TOTP inválidos")
    counter = timestamp // STEP_SECONDS
    digest = hmac.new(_decode_secret(secret), struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 15
    value = struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7fffffff
    return str(value % (10 ** digits)).zfill(digits)


def match_counter(secret: str, code: str, *, timestamp: int | None = None,
                  window: int = 1, last_accepted_counter: int = -1) -> int | None:
    """Devuelve contador válido no usado; el llamante DEBE persistirlo atómicamente.

    Ventana restringida a ±1 intervalo, requiere códigos de exactamente 6 dígitos.
    """
    if not isinstance(code, str) or len(code) != CODE_DIGITS or not code.isascii() or not code.isdecimal():
        return None
    if window not in (0, 1):
        raise ValueError("Ventana TOTP inválida")
    current_time = int(time.time()) if timestamp is None else timestamp
    if not isinstance(current_time, int) or current_time < 0:
        raise ValueError("Tiempo TOTP inválido")
    current = current_time // STEP_SECONDS
    for counter in range(max(0, current - window), current + window + 1):
        if counter <= last_accepted_counter:
            continue
        if hmac.compare_digest(totp_at(secret, counter * STEP_SECONDS), code):
            return counter
    return None


def provisioning_uri(secret: str, account_label: str, *, issuer: str = "VENCIRA") -> str:
    _decode_secret(secret)
    if not account_label or len(account_label) > 200 or not issuer:
        raise ValueError("Etiqueta MFA inválida")
    label = quote(f"{issuer}:{account_label}", safe="")
    return (f"otpauth://totp/{label}?secret={secret}&issuer={quote(issuer, safe='')}"
            f"&algorithm=SHA1&digits={CODE_DIGITS}&period={STEP_SECONDS}")
