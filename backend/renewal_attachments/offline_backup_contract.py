"""Contrato experimental de recuperación: no accede a infraestructura real.

El inventario externo de BD debe proceder de una instantánea consistente.
No contiene claves y no autoriza restauraciones de producción.
"""
import base64
import hashlib
import hmac
import json
import re

from cryptography.fernet import Fernet, InvalidToken


class RecoveryContractError(Exception):
    pass


MAX_FILE = 16 * 1024 * 1024
MAX_BUNDLE = 40 * 1024 * 1024
KEY_ID = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
IDENTIFIER = re.compile(r"[0-9a-f]{32}\Z")


def _digest(data):
    return hashlib.sha256(data).hexdigest()


def _canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")


def _validate_key_id(value):
    if not isinstance(value, str) or not KEY_ID.fullmatch(value):
        raise RecoveryContractError("INVALID_KEY_VERSION")


def _validate_files(files):
    if not isinstance(files, dict) or not files:
        raise RecoveryContractError("INVALID_INVENTORY")

    if len(files) > 100:
        raise RecoveryContractError("INVENTORY_TOO_LARGE")

    for name, data in files.items():
        if not isinstance(name, str):
            raise RecoveryContractError("INVALID_OBJECT_ID")

        if name.endswith(".json"):
            object_id = name[:-5]
        else:
            object_id = name

        if not IDENTIFIER.fullmatch(object_id):
            raise RecoveryContractError("INVALID_OBJECT_ID")

        if not isinstance(data, bytes) or not 0 < len(data) <= MAX_FILE:
            raise RecoveryContractError("INVALID_OBJECT_SIZE")


def create_backup(
    *,
    encrypted_files,
    journal_files,
    backup_key,
    backup_key_id,
    attachment_key_id,
    snapshot_id,
):
    """Cifra un inventario de bytes ya cifrados y un diario sintético.

    snapshot_id vincula el paquete con una captura de BD externa.
    El vínculo no demuestra por sí solo consistencia temporal.
    """
    _validate_key_id(backup_key_id)
    _validate_key_id(attachment_key_id)
    _validate_key_id(snapshot_id)

    _validate_files(encrypted_files)
    _validate_files(journal_files)

    if any(not k.endswith(".json") for k in journal_files):
        raise RecoveryContractError("INVALID_JOURNAL_ENTRY")
    if any(k.endswith(".json") for k in encrypted_files):
        raise RecoveryContractError("INVALID_ENCRYPTED_ENTRY")

    object_ids = set(encrypted_files)
    journal_ids = {name[:-5] for name in journal_files}

    if object_ids != journal_ids:
        raise RecoveryContractError("UNPAIRED_OBJECTS")

    all_files = {**encrypted_files, **journal_files}

    payload = {
        "schema": 1,
        "backup_key_id": backup_key_id,
        "attachment_key_id": attachment_key_id,
        "snapshot_id": snapshot_id,
        "manifest": {
            name: _digest(data)
            for name, data in all_files.items()
        },
        "files": {
            name: base64.b64encode(data).decode("ascii")
            for name, data in all_files.items()
        },
    }

    try:
        encrypted = Fernet(backup_key).encrypt(_canonical(payload))
    except (TypeError, ValueError) as exc:
        raise RecoveryContractError("INVALID_BACKUP_KEY") from exc

    if len(encrypted) > MAX_BUNDLE:
        raise RecoveryContractError("BUNDLE_TOO_LARGE")

    return encrypted


def inspect_backup(
    *,
    bundle,
    backup_key,
    expected_backup_key_id,
    expected_attachment_key_id,
    expected_snapshot_id,
    expected_object_digests,
):
    """Verificación sin escribir archivos.

    expected_object_digests se obtiene del inventario externo de BD,
    no del propio paquete. Contiene SHA-256 de los objetos cifrados.
    """
    for value in (
        expected_backup_key_id,
        expected_attachment_key_id,
        expected_snapshot_id,
    ):
        _validate_key_id(value)

    if (
        not isinstance(bundle, bytes)
        or not 0 < len(bundle) <= MAX_BUNDLE
    ):
        raise RecoveryContractError("INVALID_BUNDLE")

    try:
        plaintext = Fernet(backup_key).decrypt(bundle)
        payload = json.loads(plaintext)

        if not isinstance(payload, dict) or set(payload) != {
            "schema", "backup_key_id", "attachment_key_id",
            "snapshot_id", "manifest", "files"
        }:
            raise ValueError("Invalid schema")

        if payload["schema"] != 1:
            raise ValueError("Invalid version")

        if (
            payload["backup_key_id"] != expected_backup_key_id
            or payload["attachment_key_id"] != expected_attachment_key_id
            or payload["snapshot_id"] != expected_snapshot_id
        ):
            raise ValueError("Version mismatch")

        files = payload["files"]
        manifest = payload["manifest"]

        if not isinstance(files, dict) or not isinstance(manifest, dict):
            raise ValueError("Invalid inventory")

        raw = {
            name: base64.b64decode(value, validate=True)
            for name, value in files.items()
        }

        if any(not isinstance(value, str) for value in files.values()):
            raise ValueError("Invalid encoding")

        _validate_files(raw)

        if set(manifest) != set(raw):
            raise ValueError("Incomplete inventory")

        for name, data in raw.items():
            digest = manifest[name]
            if (
                not isinstance(digest, str)
                or not hmac.compare_digest(_digest(data), digest)
            ):
                raise ValueError("Object integrity mismatch")

        encrypted = {
            name: value for name, value in raw.items()
            if not name.endswith(".json")
        }
        journals = {
            name[:-5] for name in raw
            if name.endswith(".json")
        }

        if set(encrypted) != journals:
            raise ValueError("Unpaired objects")

        if (
            not isinstance(expected_object_digests, dict)
            or set(expected_object_digests) != set(encrypted)
        ):
            raise ValueError("Database inventory mismatch")

        for name, data in encrypted.items():
            expected = expected_object_digests[name]
            if (
                not isinstance(expected, str)
                or not hmac.compare_digest(
                    _digest(data), expected
                )
            ):
                raise ValueError("Database digest mismatch")

        return {
            "verified": True,
            "objects": len(encrypted),
            "snapshot_id": expected_snapshot_id,
            "backup_key_id": expected_backup_key_id,
            "attachment_key_id": expected_attachment_key_id,
        }

    except (
        InvalidToken, TypeError, ValueError, KeyError,
        AttributeError, OverflowError, UnicodeError,
        RecoveryContractError
    ) as exc:
        raise RecoveryContractError(
            "RECOVERY_VERIFICATION_FAILED"
        ) from exc
