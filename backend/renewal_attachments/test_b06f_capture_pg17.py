"""B06F: captura sintética coordinada en PostgreSQL 17.

No realiza backup real ni opera sobre DEV/O5.
"""
import hashlib
import json
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import date

from cryptography.fernet import Fernet
from django.db import (
    connection, connections, close_old_connections,
)
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace

from .models import RenewalAttachment
from .offline_write_barrier_b06b import advisory_barrier
from .offline_capture_fence import verify_capture_fence
from .offline_backup_contract import create_backup
from .offline_restore_reconcile import reconcile_restored_content


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(data):
    return json.dumps(
        data, sort_keys=True, separators=(",", ":")
    ).encode()


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B06FCoordinatedCaptureTests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")

        workspace = Workspace.objects.create(
            name="B06F SYNTHETIC"
        )
        renewal = Renewal.objects.create(
            workspace=workspace,
            full_name="Synthetic",
            customer_reference="B06F",
            expires_on=date(2027, 12, 1),
        )

        self.original = b"B06F SYNTHETIC TEST DOCUMENT"
        self.attachment_key = Fernet.generate_key()
        self.backup_key = Fernet.generate_key()

        self.ciphertext = Fernet(
            self.attachment_key
        ).encrypt(self.original)

        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(self.original),
            sha256=digest(self.original),
            state=RenewalAttachment.State.QUARANTINED,
        )

        self.key = self.item.storage_key.hex

        self.journal = canonical({
            "version": 1,
            "storage_key": self.key,
            "sha256": digest(self.original),
            "state": "pending",
        })

        # Simula inventario inmutable del almacén privado.
        # No se usan documentos de clientes ni claves reales.
        self.object_inventory = {
            self.key: self.ciphertext
        }
        self.journal_inventory = {
            self.key + ".json": self.journal
        }

    def capture(self):
        with advisory_barrier(capture=True, timeout=4):
            rows = list(
                RenewalAttachment.objects.filter(
                    pk=self.item.pk
                ).values(
                    "storage_key",
                    "sha256",
                    "byte_size",
                )
            )
            self.assertEqual(len(rows), 1)

            db_metadata = {
                row["storage_key"].hex: {
                    "sha256": row["sha256"],
                    "byte_size": row["byte_size"],
                }
                for row in rows
            }

            external_cipher_digests = {
                key: digest(data)
                for key, data in self.object_inventory.items()
            }

            # B06A usa inventarios de ciphertext.
            # Aquí se asocian a la misma captura sintética.
            captured_db_inventory = dict(
                external_cipher_digests
            )

            marker = {
                "epoch": 1,
                "snapshot": "b06f-pg17",
                "inventory_digest": digest(
                    canonical(captured_db_inventory)
                ),
            }

            fence = verify_capture_fence(
                before=marker,
                after=dict(marker),
                database_inventory=captured_db_inventory,
                object_inventory=external_cipher_digests,
            )

            bundle = create_backup(
                encrypted_files=dict(
                    self.object_inventory
                ),
                journal_files=dict(
                    self.journal_inventory
                ),
                backup_key=self.backup_key,
                backup_key_id="backup-v1",
                attachment_key_id="attachment-v1",
                snapshot_id="b06f-pg17",
            )

        result = reconcile_restored_content(
            bundle=bundle,
            backup_key=self.backup_key,
            attachment_key=self.attachment_key,
            backup_key_id="backup-v1",
            attachment_key_id="attachment-v1",
            snapshot_id="b06f-pg17",
            expected_metadata=db_metadata,
            expected_ciphertext_digests=external_cipher_digests,
        )
        return fence, result

    def test_capture_and_reconciliation(self):
        fence, recovered = self.capture()
        self.assertTrue(fence["consistent"])
        self.assertTrue(recovered["verified"])
        self.assertTrue(recovered["content_reconciled"])
        self.assertTrue(recovered["journal_reconciled"])
        self.assertFalse(recovered["release_authorized"])

    def test_exclusive_capture_blocks_writer(self):
        started = threading.Event()
        entered = threading.Event()

        def writer():
            close_old_connections()
            try:
                started.set()
                with advisory_barrier(
                    capture=False, timeout=4
                ):
                    entered.set()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(
                capture=True, timeout=4
            ):
                future = pool.submit(writer)
                self.assertTrue(started.wait(3))
                self.assertFalse(entered.wait(0.25))

            future.result(timeout=6)

        self.assertTrue(entered.is_set())

    def test_failure_releases_barrier(self):
        with self.assertRaises(ValueError):
            with advisory_barrier(
                capture=True, timeout=2
            ):
                raise ValueError("synthetic capture failure")

        with advisory_barrier(
            capture=False, timeout=2
        ):
            pass
