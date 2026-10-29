"""B09E: gate sintético de restauración cifrada.

No expuesto mediante HTTP. Solo contenedores b07 de ensayo.
No modifica producción, O5 ni el almacén real.
"""
import base64
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

os.environ.setdefault(
    "DJANGO_SETTINGS_MODULE", "config.settings"
)

import django
django.setup()

from cryptography.fernet import Fernet
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection

from .models import RenewalAttachment
from .offline_backup_contract import create_backup
from .offline_db_envelope_b08 import seal_database_dump
from .offline_backup_manifest_b09 import create_manifest
from .offline_verified_restore_b09 import (
    verify_backup_set_and_restore,
)


SNAPSHOT = "b09e-pg17"
DB_KEY_ID = "b09e-database-v1"
BUNDLE_KEY_ID = "b07-backup-v1"
CONTENT_KEY_ID = "b07-attachment-v1"
MANIFEST_KEY_ID = "b09e-manifest-v1"


def sha(value):
    return hashlib.sha256(value).hexdigest()


def guard():
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
        or os.getenv("B09E_DISPOSABLE_DB") != "1"
        or os.getenv("B07_DISPOSABLE_DB") != "1"
        or os.getenv("POSTGRES_DB") != "b07"
        or not os.getenv(
            "POSTGRES_HOST", ""
        ).startswith("vencira-b07-")
    ):
        raise PermissionDenied("B09E_DISPOSABLE_ONLY")


def read(path, maximum):
    if path.is_symlink() or not path.is_file():
        raise RuntimeError("B09E_INVALID_FILE")
    if not 0 < path.stat().st_size <= maximum:
        raise RuntimeError("B09E_INVALID_SIZE")
    return path.read_bytes()


def write(path, data):
    with path.open("xb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())


def catalog_paths(root):
    return root / "capture", root / "keys"


def build(root):
    capture, keys = catalog_paths(root)
    fixture = root / "fixture"

    original_dump = read(root / "source.dump", 32 * 1024 * 1024)
    db_key = Fernet.generate_key()
    manifest_key = os.urandom(32)

    backup_key = read(keys / "backup.key", 1024)
    attachment_key = read(keys / "attachment.key", 1024)

    old = json.loads(
        Fernet(backup_key).decrypt(
            read(fixture / "bundle.enc", 40 * 1024 * 1024)
        )
    )

    identifier = read(
        fixture / "storage_key", 64
    ).decode()

    encrypted_file = base64.b64decode(
        old["files"][identifier], validate=True
    )
    journal = base64.b64decode(
        old["files"][identifier + ".json"], validate=True
    )

    # Reempaquetar con el MISMO snapshot del dump.
    bundle = create_backup(
        encrypted_files={identifier: encrypted_file},
        journal_files={identifier + ".json": journal},
        backup_key=backup_key,
        backup_key_id=BUNDLE_KEY_ID,
        attachment_key_id=CONTENT_KEY_ID,
        snapshot_id=SNAPSHOT,
    )

    db_envelope = seal_database_dump(
        dump_bytes=original_dump,
        key=db_key,
        key_id=DB_KEY_ID,
        snapshot_id=SNAPSHOT,
    )

    manifest = create_manifest(
        database_envelope=db_envelope,
        attachment_bundle=bundle,
        snapshot_id=SNAPSHOT,
        database_key_id=DB_KEY_ID,
        attachment_key_id=BUNDLE_KEY_ID,
        manifest_key_id=MANIFEST_KEY_ID,
        authentication_key=manifest_key,
    )

    rows = list(
        RenewalAttachment.objects.filter(
            storage_key=identifier
        ).values("storage_key", "sha256", "byte_size")
    )
    if len(rows) != 1:
        raise RuntimeError("B09E_SOURCE_ORM_MISSING")

    row = rows[0]
    external_catalog = {
        "snapshot": SNAPSHOT,
        "db_digest": sha(original_dump),
        "identifier": identifier,
        "cipher_digest": sha(encrypted_file),
        "plain_digest": row["sha256"],
        "byte_size": row["byte_size"],
    }

    write(capture / "database.enc", db_envelope)
    write(capture / "attachments.enc", bundle)
    write(capture / "manifest.json", manifest)

    write(keys / "database.key", db_key)
    write(keys / "manifest.key", manifest_key)
    write(
        keys / "catalog.json",
        json.dumps(
            external_catalog, sort_keys=True
        ).encode()
    )

    print("B09E_AUTHENTICATED_SET_CREATED=OK")


def recovery_args(root):
    capture, keys = catalog_paths(root)
    catalog = json.loads(
        read(keys / "catalog.json", 4096)
    )

    identifier = catalog["identifier"]

    return dict(
        manifest=read(
            capture / "manifest.json", 4096
        ),
        database_envelope=read(
            capture / "database.enc", 48 * 1024 * 1024
        ),
        attachment_bundle=read(
            capture / "attachments.enc", 40 * 1024 * 1024
        ),
        manifest_key=read(keys / "manifest.key", 1024),
        database_key=read(keys / "database.key", 1024),
        backup_key=read(keys / "backup.key", 1024),
        attachment_key=read(keys / "attachment.key", 1024),
        snapshot_id=SNAPSHOT,
        database_key_id=DB_KEY_ID,
        attachment_bundle_key_id=BUNDLE_KEY_ID,
        attachment_content_key_id=CONTENT_KEY_ID,
        manifest_key_id=MANIFEST_KEY_ID,
        expected_database_sha256=catalog["db_digest"],
        expected_metadata={
            identifier: {
                "sha256": catalog["plain_digest"],
                "byte_size": catalog["byte_size"],
            }
        },
        expected_ciphertext_digests={
            identifier: catalog["cipher_digest"]
        },
    )


def recover(root):
    result = verify_backup_set_and_restore(
        **recovery_args(root)
    )
    if not result["verified"] or result["release_authorized"]:
        raise RuntimeError("B09E_GATE_REJECTED")

    # Solo salida binaria: se conecta directamente a pg_restore.
    sys.stdout.buffer.write(result["database_bytes"])
    sys.stdout.buffer.flush()


def verify(root):
    catalog = json.loads(
        read(root / "keys" / "catalog.json", 4096)
    )
    rows = list(
        RenewalAttachment.objects.filter(
            storage_key=catalog["identifier"]
        ).values("storage_key", "sha256", "byte_size")
    )
    if len(rows) != 1:
        raise RuntimeError("B09E_TARGET_ORM_MISSING")

    row = rows[0]
    if (
        row["sha256"] != catalog["plain_digest"]
        or row["byte_size"] != catalog["byte_size"]
    ):
        raise RuntimeError("B09E_TARGET_ORM_MISMATCH")

    result = verify_backup_set_and_restore(
        **recovery_args(root)
    )
    if not result["verified"] or result["release_authorized"]:
        raise RuntimeError("B09E_FINAL_GATE_REJECTED")

    print("B09E_RESTORED_ORM=OK")
    print("B09E_RESTORED_CONTENT_AND_JOURNAL=OK")
    print("B09E_MANIFEST_REVALIDATED=OK")


def negative(root):
    from .offline_backup_manifest_b09 import BackupManifestError

    args = recovery_args(root)
    alterations = [
        {"manifest_key": os.urandom(32)},
        {"database_envelope": b"replaced database"},
        {"attachment_bundle": b"replaced attachment"},
        {"snapshot_id": "wrong-snapshot"},
    ]
    for change in alterations:
        try:
            verify_backup_set_and_restore(
                **{**args, **change}
            )
        except BackupManifestError:
            continue
        raise RuntimeError("B09E_NEGATIVE_ACCEPTED")

    print("B09E_MIXED_SET_REJECTED=OK")
    print("B09E_MANIFEST_KEY_REJECTED=OK")


if __name__ == "__main__":
    guard()
    if len(sys.argv) != 3:
        raise SystemExit("B09E_USAGE")

    root = Path(sys.argv[2])
    if (
        not root.is_dir()
        or root.is_symlink()
        or root.stat().st_mode & 0o077
    ):
        raise SystemExit("B09E_UNSAFE_WORKDIR")

    commands = {
        "build": build,
        "recover": recover,
        "verify": verify,
        "negative": negative,
    }
    if sys.argv[1] not in commands:
        raise SystemExit("B09E_INVALID_ACTION")
    commands[sys.argv[1]](root)
