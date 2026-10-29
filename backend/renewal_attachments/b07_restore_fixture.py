"""B07: fixture de restauración. Exclusivo para PG17 temporal.

Ejecución mediante python -m renewal_attachments.b07_restore_fixture
create|verify /scratch. Nunca habilitar como endpoint.
"""
import hashlib
import json
import os
import stat
import sys
from datetime import date
from pathlib import Path

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django
django.setup()

from cryptography.fernet import Fernet
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection

from reminders.models import Workspace, Renewal
from .models import RenewalAttachment
from .offline_backup_contract import (
    create_backup, RecoveryContractError,
)
from .offline_restore_reconcile import reconcile_restored_content
from .offline_write_barrier_b06b import advisory_barrier


def sha(data):
    return hashlib.sha256(data).hexdigest()


def guard():
    if (
        settings.VENCIRA_ENV != "test"
        or not settings.VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED
        or connection.vendor != "postgresql"
        or not os.environ.get("B07_DISPOSABLE_DB") == "1"
        or os.environ.get("POSTGRES_DB") != "b07"
        or not os.environ.get("POSTGRES_HOST", "").startswith(
            "vencira-b07-"
        )
    ):
        raise PermissionDenied("B07_ONLY_DISPOSABLE_PG17")


def file_write(path, data):
    with open(path, "xb") as output:
        os.chmod(path, 0o600)
        output.write(data)
        output.flush()
        os.fsync(output.fileno())


def create(root):
    guard()
    if list(root.iterdir()):
        raise RuntimeError("B07_SCRATCH_NOT_EMPTY")

    plaintext = b"B07 SYNTHETIC RESTORABLE CONTENT"
    attachment_key = Fernet.generate_key()
    backup_key = Fernet.generate_key()

    with advisory_barrier(capture=False):
        ws = Workspace.objects.create(
            name="B07 SYNTHETIC WORKSPACE"
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B07-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(plaintext),
            sha256=sha(plaintext),
            state=RenewalAttachment.State.QUARANTINED,
        )

    key = item.storage_key.hex
    ciphertext = Fernet(attachment_key).encrypt(plaintext)
    journal = json.dumps({
        "version": 1,
        "storage_key": key,
        "sha256": sha(plaintext),
        "state": "pending",
    }, sort_keys=True).encode()

    # Única sección exclusiva que produce la captura y su
    # inventario. En este entorno no hay otros escritores.
    with advisory_barrier(capture=True):
        rows = list(
            RenewalAttachment.objects.filter(
                pk=item.pk
            ).values("storage_key", "sha256", "byte_size")
        )
        if len(rows) != 1:
            raise RuntimeError("B07_SOURCE_METADATA_MISSING")
        record = rows[0]
        if (
            record["storage_key"].hex != key
            or record["sha256"] != sha(plaintext)
            or record["byte_size"] != len(plaintext)
        ):
            raise RuntimeError("B07_SOURCE_METADATA_MISMATCH")

        bundle = create_backup(
            encrypted_files={key: ciphertext},
            journal_files={key + ".json": journal},
            backup_key=backup_key,
            backup_key_id="b07-backup-v1",
            attachment_key_id="b07-attachment-v1",
            snapshot_id="b07-pg17",
        )

        file_write(root / "bundle.enc", bundle)
        file_write(root / "backup.key", backup_key)
        file_write(root / "attachment.key", attachment_key)
        file_write(root / "storage_key", key.encode())
        file_write(
            root / "external_cipher_digest",
            sha(ciphertext).encode()
        )

    print("B07_SOURCE_ORM=OK")
    print("B07_ENCRYPTED_PACKAGE=OK")


def verify(root):
    guard()
    key = (root / "storage_key").read_text()
    if len(key) != 32:
        raise RuntimeError("B07_INVALID_KEY_ID")

    rows = list(
        RenewalAttachment.objects.filter(
            storage_key=key
        ).values("storage_key", "sha256", "byte_size")
    )
    if len(rows) != 1:
        raise RuntimeError("B07_RESTORED_METADATA_MISSING")

    record = rows[0]
    metadata = {
        key: {
            "sha256": record["sha256"],
            "byte_size": record["byte_size"],
        }
    }
    cipher_digest = (
        root / "external_cipher_digest"
    ).read_text()

    args = dict(
        bundle=(root / "bundle.enc").read_bytes(),
        backup_key=(root / "backup.key").read_bytes(),
        attachment_key=(root / "attachment.key").read_bytes(),
        backup_key_id="b07-backup-v1",
        attachment_key_id="b07-attachment-v1",
        snapshot_id="b07-pg17",
        expected_metadata=metadata,
        expected_ciphertext_digests={
            key: cipher_digest,
        },
    )

    result = reconcile_restored_content(**args)
    if not (
        result["verified"]
        and result["content_reconciled"]
        and result["journal_reconciled"]
        and not result["release_authorized"]
    ):
        raise RuntimeError("B07_RECONCILIATION_REJECTED")

    print("B07_RESTORED_DB_RECONCILIATION=OK")
    print("B07_CONTENT_AND_JOURNAL=OK")

    # Prueba negativa: una clave incorrecta no debe permitir
    # recuperar el contenido original.
    try:
        reconcile_restored_content(
            **{
                **args,
                "attachment_key": Fernet.generate_key(),
            }
        )
    except RecoveryContractError:
        print("B07_WRONG_KEY_REJECTED=OK")
    else:
        raise RuntimeError("B07_WRONG_KEY_ACCEPTED")

    # Prueba negativa: metadatos falsificados.
    try:
        reconcile_restored_content(
            **{
                **args,
                "expected_metadata": {
                    key: {
                        "sha256": "0" * 64,
                        "byte_size": record["byte_size"],
                    }
                },
            }
        )
    except RecoveryContractError:
        print("B07_TAMPERED_METADATA_REJECTED=OK")
    else:
        raise RuntimeError("B07_TAMPER_ACCEPTED")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in {
        "create", "verify"
    }:
        raise SystemExit("B07_BAD_COMMAND")

    folder = Path(sys.argv[2])
    if not folder.is_dir():
        raise SystemExit("B07_MISSING_PRIVATE_DIRECTORY")

    mode = folder.stat().st_mode
    if not stat.S_ISDIR(mode) or mode & 0o077:
        raise SystemExit("B07_UNSAFE_DIRECTORY")

    if sys.argv[1] == "create":
        create(folder)
    else:
        verify(folder)
