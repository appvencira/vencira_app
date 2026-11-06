"""B08A: cifrado experimental del dump PostgreSQL.

No accede a BD, O5 ni filesystem.
La clave debe obtenerse de un custodio independiente.
"""
import base64
import hashlib
import hmac
import json
import re

from cryptography.fernet import Fernet, InvalidToken


MAX_DUMP = 32 * 1024 * 1024
MAX_ENVELOPE = 48 * 1024 * 1024
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")


class DatabaseEnvelopeError(Exception):
    pass


def _validate_id(value):
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise DatabaseEnvelopeError("INVALID_IDENTIFIER")


def seal_database_dump(
    *,
    dump_bytes,
    key,
    key_id,
    snapshot_id,
):
    """Devuelve únicamente el paquete cifrado, nunca la clave."""
    _validate_id(key_id)
    _validate_id(snapshot_id)

    if (
        not isinstance(dump_bytes, bytes)
        or not 0 < len(dump_bytes) <= MAX_DUMP
    ):
        raise DatabaseEnvelopeError("INVALID_DUMP_SIZE")

    payload = {
        "schema": 1,
        "key_id": key_id,
        "snapshot_id": snapshot_id,
        "sha256": hashlib.sha256(dump_bytes).hexdigest(),
        "data": base64.b64encode(dump_bytes).decode("ascii"),
    }

    try:
        encoded = json.dumps(
            payload,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")

        result = Fernet(key).encrypt(encoded)
    except (TypeError, ValueError) as exc:
        raise DatabaseEnvelopeError("INVALID_ENCRYPTION_KEY") from exc

    if len(result) > MAX_ENVELOPE:
        raise DatabaseEnvelopeError("ENVELOPE_TOO_LARGE")

    return result


def open_database_dump(
    *,
    envelope,
    key,
    expected_key_id,
    expected_snapshot_id,
    expected_sha256,
):
    """Verifica paquete y devuelve bytes exclusivamente en memoria."""
    _validate_id(expected_key_id)
    _validate_id(expected_snapshot_id)

    if (
        not isinstance(envelope, bytes)
        or not 0 < len(envelope) <= MAX_ENVELOPE
        or not isinstance(expected_sha256, str)
        or not re.fullmatch(r"[0-9a-f]{64}", expected_sha256)
    ):
        raise DatabaseEnvelopeError("INVALID_INPUT")

    try:
        payload = json.loads(Fernet(key).decrypt(envelope))

        if not isinstance(payload, dict) or set(payload) != {
            "schema", "key_id", "snapshot_id", "sha256", "data"
        }:
            raise ValueError("invalid payload")

        if type(payload["schema"]) is not int or payload["schema"] != 1:
            raise ValueError("invalid schema")

        if (
            payload["key_id"] != expected_key_id
            or payload["snapshot_id"] != expected_snapshot_id
        ):
            raise ValueError("wrong identity")

        if not isinstance(payload["data"], str):
            raise ValueError("invalid data")

        restored = base64.b64decode(
            payload["data"], validate=True
        )

        if not 0 < len(restored) <= MAX_DUMP:
            raise ValueError("invalid size")

        digest = hashlib.sha256(restored).hexdigest()
        if (
            not isinstance(payload["sha256"], str)
            or not hmac.compare_digest(digest, payload["sha256"])
            or not hmac.compare_digest(digest, expected_sha256)
        ):
            raise ValueError("integrity failure")

        return restored

    except (
        InvalidToken, ValueError, TypeError, KeyError,
        AttributeError, OverflowError, UnicodeError
    ) as exc:
        raise DatabaseEnvelopeError(
            "DATABASE_ENVELOPE_VERIFICATION_FAILED"
        ) from exc
