"""B05E: recuperación sintética contra modelo Django en PG17.

Nunca usa BD activa, O5, claves ni documentos reales.
"""
import hashlib
import json
import uuid
from datetime import date

from cryptography.fernet import Fernet
from django.conf import settings
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from .models import RenewalAttachment
from .offline_backup_contract import (
    create_backup, RecoveryContractError
)
from .offline_restore_reconcile import (
    reconcile_restored_content
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B05EPostgresRecoveryTests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        self.assertEqual(settings.VENCIRA_ENV, "test")

        workspace = Workspace.objects.create(
            name="B05E SYNTHETIC"
        )
        renewal = Renewal.objects.create(
            workspace=workspace,
            customer_reference="B05E-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )

        self.document = b"B05E SYNTHETIC DOCUMENT"
        self.attachment_key = Fernet.generate_key()
        self.backup_key = Fernet.generate_key()
        self.ciphertext = Fernet(
            self.attachment_key
        ).encrypt(self.document)

        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(self.document),
            sha256=hashlib.sha256(
                self.document
            ).hexdigest(),
            state=RenewalAttachment.State.QUARANTINED,
        )

        self.identifier = self.item.storage_key.hex

        self.journal = json.dumps({
            "version": 1,
            "storage_key": self.identifier,
            "sha256": self.item.sha256,
            "state": "pending",
        }).encode()

        self.bundle = create_backup(
            encrypted_files={
                self.identifier: self.ciphertext,
            },
            journal_files={
                self.identifier + ".json": self.journal,
            },
            backup_key=self.backup_key,
            backup_key_id="backup-v1",
            attachment_key_id="attachment-v1",
            snapshot_id="b05e-pg17",
        )

    def external_inventory(self):
        # Esta lectura procede del ORM PostgreSQL,
        # no del paquete cifrado.
        rows = list(
            RenewalAttachment.objects.filter(
                pk=self.item.pk
            ).values(
                "storage_key", "sha256", "byte_size"
            )
        )
        self.assertEqual(len(rows), 1)

        row = rows[0]
        return {
            row["storage_key"].hex: {
                "sha256": row["sha256"],
                "byte_size": row["byte_size"],
            }
        }

    def reconcile(self, **changes):
        args = {
            "bundle": self.bundle,
            "backup_key": self.backup_key,
            "attachment_key": self.attachment_key,
            "backup_key_id": "backup-v1",
            "attachment_key_id": "attachment-v1",
            "snapshot_id": "b05e-pg17",
            "expected_metadata": self.external_inventory(),
            "expected_ciphertext_digests": {
                self.identifier: hashlib.sha256(
                    self.ciphertext
                ).hexdigest()
            },
        }
        args.update(changes)
        return reconcile_restored_content(**args)

    def test_real_model_reconciles_synthetic_content(self):
        result = self.reconcile()
        self.assertTrue(result["verified"])
        self.assertTrue(result["journal_reconciled"])
        self.assertTrue(result["content_reconciled"])
        self.assertFalse(result["release_authorized"])

    def test_modified_database_digest_rejected(self):
        RenewalAttachment.objects.filter(
            pk=self.item.pk
        ).update(sha256="0" * 64)

        with self.assertRaises(RecoveryContractError):
            self.reconcile()

    def test_modified_database_size_rejected(self):
        RenewalAttachment.objects.filter(
            pk=self.item.pk
        ).update(byte_size=len(self.document) + 1)

        with self.assertRaises(RecoveryContractError):
            self.reconcile()

    def test_wrong_encryption_key_rejected(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(
                attachment_key=Fernet.generate_key()
            )

    def test_cross_snapshot_rejected(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(
                snapshot_id="different-snapshot"
            )

    def test_missing_external_metadata_rejected(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(expected_metadata={})
