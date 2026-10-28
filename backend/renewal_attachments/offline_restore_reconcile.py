"""Conciliación de recuperación con bytes originales y diario.

Exclusivamente experimental: no escribe archivos, no consulta BD,
no autoriza descargas ni restaura datos de producción.
"""
import base64
import hashlib
import hmac
import json
import re

from cryptography.fernet import Fernet
from .offline_backup_contract import (
    inspect_backup,
    RecoveryContractError,
)


ID = re.compile(r"[0-9a-f]{32}\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")


def reconcile_restored_content(
    *,
    bundle,
    backup_key,
    attachment_key,
    backup_key_id,
    attachment_key_id,
    snapshot_id,
    expected_metadata,
    expected_ciphertext_digests,
):
    """Contrasta respaldo, diario y metadatos de una BD externa.

    Los diccionarios expected_* deben proceder de una fuente
    independiente y consistente, no del propio backup.
    """
    try:
        if (
            not isinstance(expected_metadata, dict)
            or not expected_metadata
            or len(expected_metadata) > 100
            or not isinstance(expected_ciphertext_digests, dict)
            or set(expected_metadata)
            != set(expected_ciphertext_digests)
        ):
            raise ValueError("invalid external inventory")

        for identifier, metadata in expected_metadata.items():
            if not isinstance(identifier, str) or not ID.fullmatch(identifier):
                raise ValueError("invalid identifier")
            if not isinstance(metadata, dict) or set(metadata) != {
                "sha256", "byte_size"
            }:
                raise ValueError("invalid metadata")
            if (
                not isinstance(metadata["sha256"], str)
                or not SHA.fullmatch(metadata["sha256"])
                or type(metadata["byte_size"]) is not int
                or not 0 < metadata["byte_size"] <= 10 * 1024 * 1024
            ):
                raise ValueError("invalid digest or size")

        verified = inspect_backup(
            bundle=bundle,
            backup_key=backup_key,
            expected_backup_key_id=backup_key_id,
            expected_attachment_key_id=attachment_key_id,
            expected_snapshot_id=snapshot_id,
            expected_object_digests=expected_ciphertext_digests,
        )

        # El contrato anterior ha autenticado el paquete completo.
        from cryptography.fernet import Fernet as BackupFernet
        payload = json.loads(BackupFernet(backup_key).decrypt(bundle))
        files = payload["files"]

        attachment_cipher = Fernet(attachment_key)

        for identifier, metadata in expected_metadata.items():
            ciphertext = base64.b64decode(
                files[identifier], validate=True
            )
            plaintext = attachment_cipher.decrypt(ciphertext)

            actual_hash = hashlib.sha256(plaintext).hexdigest()

            if (
                len(plaintext) != metadata["byte_size"]
                or not hmac.compare_digest(
                    actual_hash, metadata["sha256"]
                )
            ):
                raise ValueError("document mismatch")

            journal = json.loads(
                base64.b64decode(
                    files[identifier + ".json"],
                    validate=True,
                )
            )

            if (
                not isinstance(journal, dict)
                or set(journal) != {
                    "version", "storage_key", "sha256", "state"
                }
                or type(journal["version"]) is not int
                or journal["version"] != 1
                or journal["storage_key"] != identifier
                or journal["state"] != "pending"
                or not isinstance(journal["sha256"], str)
                or not hmac.compare_digest(
                    journal["sha256"], actual_hash
                )
            ):
                raise ValueError("journal mismatch")

        return {
            "verified": True,
            "objects": verified["objects"],
            "content_reconciled": True,
            "journal_reconciled": True,
            "release_authorized": False,
        }

    except Exception as exc:
        if isinstance(exc, (KeyboardInterrupt, SystemExit)):
            raise
        raise RecoveryContractError(
            "RESTORED_CONTENT_RECONCILIATION_FAILED"
        ) from exc
