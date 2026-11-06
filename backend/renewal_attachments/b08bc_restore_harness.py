"""B08B/C: ensayo offline de restauración cifrada.

No es una herramienta de producción ni un endpoint.
La restauración se emite por stdout, exclusivamente
para conectarla al pg_restore temporal.
"""
import hashlib
import os
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

from .offline_db_envelope_b08 import (
    DatabaseEnvelopeError,
    seal_database_dump,
    open_database_dump,
)
from .offline_restore_reconcile import (
    reconcile_restored_content,
)
from .offline_backup_contract import RecoveryContractError
from .models import RenewalAttachment


def sha(data):
    return hashlib.sha256(data).hexdigest()


def guard():
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
        or os.environ.get("B08BC_DISPOSABLE_DB") != "1"
        or os.environ.get("POSTGRES_DB") != "b08bc"
        or not os.environ.get(
            "POSTGRES_HOST", ""
        ).startswith("vencira-b08bc-")
    ):
        raise PermissionDenied(
            "B08BC_DISPOSABLE_PG17_ONLY"
        )


def read(path, limit):
    if not path.is_file() or path.is_symlink():
        raise RuntimeError("B08BC_INVALID_FILE")
    if not 0 < path.stat().st_size <= limit:
        raise RuntimeError("B08BC_INVALID_FILE_SIZE")
    return path.read_bytes()


def write_private(path, content):
    with path.open("xb") as output:
        os.chmod(path, 0o600)
        output.write(content)
        output.flush()
        os.fsync(output.fileno())


def db_args(root, keys):
    return {
        "envelope": read(
            root / "database.enc", 48 * 1024 * 1024
        ),
        "key": read(keys / "database.key", 1024),
        "expected_key_id": "b08-database-v1",
        "expected_snapshot_id": "b08bc-pg17",
        "expected_sha256": read(
            keys / "database.sha256", 128
        ).decode(),
    }


def seal(root, keys):
    raw = read(root / "source.dump", 32 * 1024 * 1024)
    encrypted = seal_database_dump(
        dump_bytes=raw,
        key=read(keys / "database.key", 1024),
        key_id="b08-database-v1",
        snapshot_id="b08bc-pg17",
    )
    write_private(root / "database.enc", encrypted)
    write_private(
        keys / "database.sha256",
        sha(raw).encode(),
    )
    print("B08BC_DATABASE_ENCRYPTED=OK")


def negative(root, keys):
    args = db_args(root, keys)

    cases = (
        {"key": Fernet.generate_key()},
        {"expected_snapshot_id": "wrong-snapshot"},
        {"expected_key_id": "wrong-key-version"},
        {"expected_sha256": "0" * 64},
        {
            "envelope":
                args["envelope"][:-1]
                + bytes([args["envelope"][-1] ^ 1])
        },
    )

    for mutation in cases:
        try:
            open_database_dump(
                **{**args, **mutation}
            )
        except DatabaseEnvelopeError:
            continue
        raise RuntimeError(
            "B08BC_NEGATIVE_TEST_ACCEPTED"
        )

    print("B08BC_WRONG_KEYS_REJECTED=OK")
    print("B08BC_CROSS_SNAPSHOT_REJECTED=OK")
    print("B08BC_TAMPER_REJECTED=OK")


def stream(root, keys):
    raw = open_database_dump(**db_args(root, keys))
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


def verify(root, keys):
    item_id = read(
        root / "fixture" / "storage_key", 64
    ).decode()

    rows = list(
        RenewalAttachment.objects.filter(
            storage_key=item_id
        ).values(
            "storage_key", "sha256", "byte_size"
        )
    )

    if len(rows) != 1:
        raise RuntimeError(
            "B08BC_RESTORED_DB_RECORD_MISSING"
        )

    record = rows[0]

    metadata = {
        record["storage_key"].hex: {
            "sha256": record["sha256"],
            "byte_size": record["byte_size"],
        }
    }

    result = reconcile_restored_content(
        bundle=read(
            root / "fixture" / "bundle.enc",
            40 * 1024 * 1024,
        ),
        backup_key=read(
            keys / "backup.key", 1024
        ),
        attachment_key=read(
            keys / "attachment.key", 1024
        ),
        backup_key_id="b07-backup-v1",
        attachment_key_id="b07-attachment-v1",
        snapshot_id="b07-pg17",
        expected_metadata=metadata,
        expected_ciphertext_digests={
            item_id: read(
                root / "fixture"
                / "external_cipher_digest", 128
            ).decode()
        },
    )

    if not (
        result["verified"]
        and result["content_reconciled"]
        and result["journal_reconciled"]
        and not result["release_authorized"]
    ):
        raise RuntimeError(
            "B08BC_RECONCILIATION_FAILED"
        )

    print("B08BC_RESTORED_DB_SCHEMA=OK")
    print("B08BC_RESTORED_CONTENT=OK")
    print("B08BC_RESTORED_JOURNAL=OK")


if __name__ == "__main__":
    guard()

    if len(sys.argv) != 4:
        raise SystemExit("B08BC_USAGE_ERROR")

    action = sys.argv[1]
    root = Path(sys.argv[2])
    keys = Path(sys.argv[3])

    if (
        not root.is_dir()
        or not keys.is_dir()
        or root.is_symlink()
        or keys.is_symlink()
        or root.stat().st_mode & 0o077
        or keys.stat().st_mode & 0o077
    ):
        raise SystemExit("B08BC_UNSAFE_DIRECTORIES")

    actions = {
        "seal": seal,
        "negative": negative,
        "stream": stream,
        "verify": verify,
    }

    if action not in actions:
        raise SystemExit("B08BC_INVALID_ACTION")

    actions[action](root, keys)
