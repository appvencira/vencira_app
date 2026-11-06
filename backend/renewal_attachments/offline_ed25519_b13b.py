"""B13B: firma asimétrica de evidencias de ensayo.

El verificador solo necesita la clave pública. No existe
endpoint, autorización de descarga ni persistencia aquí.
"""
import json
import re
import uuid
from datetime import datetime, timezone

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives import serialization


DIGEST = re.compile(r"[0-9a-f]{64}\Z")
SIGNATURE = re.compile(r"[0-9a-f]{128}\Z")


def canonical(payload):
    return json.dumps(
        payload, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def public_key_bytes(private_key):
    if not isinstance(private_key, Ed25519PrivateKey):
        raise ValueError("INVALID_PRIVATE_KEY")
    return private_key.public_key().public_bytes(
        encoding=serialization.Encoding.Raw,
        format=serialization.PublicFormat.Raw,
    )


def issue_verdict(*, private_key, attachment, engine, now=None):
    """Se ejecutará exclusivamente en el futuro servicio firmante."""
    if not isinstance(private_key, Ed25519PrivateKey):
        raise ValueError("INVALID_PRIVATE_KEY")
    if (
        type(engine) is not str
        or not 1 <= len(engine) <= 80
        or not engine.isascii()
        or getattr(attachment, "state", None) != "quarantined"
    ):
        raise ValueError("INVALID_ATTACHMENT")

    key = getattr(attachment, "storage_key", None)
    sha = getattr(attachment, "sha256", None)
    if (
        type(key) is not uuid.UUID
        or type(sha) is not str
        or not DIGEST.fullmatch(sha)
    ):
        raise ValueError("INVALID_ATTACHMENT_IDENTITY")

    instant = now if now is not None else datetime.now(timezone.utc)
    if not isinstance(instant, datetime) or instant.tzinfo is None:
        raise ValueError("INVALID_TIMESTAMP")

    payload = {
        "version": 2,
        "object_key": str(key),
        "sha256": sha,
        "verdict": "clean",
        "scanned_at": int(instant.timestamp()),
        "engine": engine,
    }
    signature = private_key.sign(
        b"VENCIRA-SCAN-ED25519-V2\x00" + canonical(payload)
    ).hex()
    return payload, signature


def verify_verdict(
    *, payload, signature, public_key,
    attachment, now=None, max_age_seconds=600,
):
    """Fail closed. Nunca crea firmas ni permite descargas."""
    try:
        if (
            type(payload) is not dict
            or set(payload) != {
                "version", "object_key", "sha256",
                "verdict", "scanned_at", "engine"
            }
            or type(payload["version"]) is not int
            or payload["version"] != 2
            or type(payload["object_key"]) is not str
            or type(payload["sha256"]) is not str
            or not DIGEST.fullmatch(payload["sha256"])
            or payload["verdict"] != "clean"
            or type(payload["engine"]) is not str
            or not 1 <= len(payload["engine"]) <= 80
            or not payload["engine"].isascii()
            or type(payload["scanned_at"]) is not int
            or type(signature) is not str
            or not SIGNATURE.fullmatch(signature)
            or type(public_key) is not bytes
            or len(public_key) != 32
            or type(max_age_seconds) is not int
            or not 1 <= max_age_seconds <= 3600
        ):
            return False

        object_key = uuid.UUID(payload["object_key"])
        if (
            str(object_key) != payload["object_key"]
            or object_key != attachment.storage_key
            or payload["sha256"] != attachment.sha256
            or attachment.state != "quarantined"
        ):
            return False

        instant = now if now is not None else datetime.now(timezone.utc)
        if not isinstance(instant, datetime) or instant.tzinfo is None:
            return False

        seconds = int(instant.timestamp())
        stamp = payload["scanned_at"]
        if stamp > seconds + 30 or seconds - stamp > max_age_seconds:
            return False

        Ed25519PublicKey.from_public_bytes(public_key).verify(
            bytes.fromhex(signature),
            b"VENCIRA-SCAN-ED25519-V2\x00" + canonical(payload),
        )
        return True

    except (
        InvalidSignature, ValueError, TypeError,
        KeyError, AttributeError, OverflowError,
        UnicodeError,
    ):
        return False
