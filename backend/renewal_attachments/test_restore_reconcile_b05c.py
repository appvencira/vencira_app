import hashlib
import json
import uuid

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .offline_backup_contract import (
    create_backup, RecoveryContractError
)
from .offline_restore_reconcile import reconcile_restored_content


class B05CReconciliationTests(SimpleTestCase):
    def setUp(self):
        self.identifier = uuid.uuid4().hex
        self.content = b"VENCIRA_B05C_SYNTHETIC_DOCUMENT"
        self.backup_key = Fernet.generate_key()
        self.attachment_key = Fernet.generate_key()

        self.ciphertext = Fernet(
            self.attachment_key
        ).encrypt(self.content)

        self.metadata = {
            self.identifier: {
                "sha256": hashlib.sha256(
                    self.content
                ).hexdigest(),
                "byte_size": len(self.content),
            }
        }

        self.cipher_digests = {
            self.identifier: hashlib.sha256(
                self.ciphertext
            ).hexdigest()
        }

        self.journal = {
            "version": 1,
            "storage_key": self.identifier,
            "sha256": self.metadata[
                self.identifier
            ]["sha256"],
            "state": "pending",
        }

    def bundle(self, journal=None):
        return create_backup(
            encrypted_files={
                self.identifier: self.ciphertext,
            },
            journal_files={
                self.identifier + ".json": json.dumps(
                    journal if journal is not None
                    else self.journal
                ).encode(),
            },
            backup_key=self.backup_key,
            backup_key_id="backup-v1",
            attachment_key_id="attachment-v1",
            snapshot_id="pg17-test-v1",
        )

    def reconcile(self, **changes):
        args = {
            "bundle": self.bundle(),
            "backup_key": self.backup_key,
            "attachment_key": self.attachment_key,
            "backup_key_id": "backup-v1",
            "attachment_key_id": "attachment-v1",
            "snapshot_id": "pg17-test-v1",
            "expected_metadata": self.metadata,
            "expected_ciphertext_digests": self.cipher_digests,
        }
        args.update(changes)
        return reconcile_restored_content(**args)

    def test_valid_recovery(self):
        result = self.reconcile()
        self.assertTrue(result["content_reconciled"])
        self.assertTrue(result["journal_reconciled"])
        self.assertFalse(result["release_authorized"])

    def test_wrong_attachment_key(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(
                attachment_key=Fernet.generate_key()
            )

    def test_wrong_document_digest(self):
        bad = {
            self.identifier: {
                **self.metadata[self.identifier],
                "sha256": "0" * 64,
            }
        }
        with self.assertRaises(RecoveryContractError):
            self.reconcile(expected_metadata=bad)

    def test_wrong_document_size(self):
        bad = {
            self.identifier: {
                **self.metadata[self.identifier],
                "byte_size": len(self.content) + 1,
            }
        }
        with self.assertRaises(RecoveryContractError):
            self.reconcile(expected_metadata=bad)

    def test_mismatched_journal(self):
        altered = {
            **self.journal,
            "sha256": "0" * 64,
        }
        with self.assertRaises(RecoveryContractError):
            self.reconcile(bundle=self.bundle(altered))

    def test_wrong_journal_identifier(self):
        altered = {
            **self.journal,
            "storage_key": uuid.uuid4().hex,
        }
        with self.assertRaises(RecoveryContractError):
            self.reconcile(bundle=self.bundle(altered))

    def test_wrong_snapshot(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(snapshot_id="different-snapshot")

    def test_missing_db_object(self):
        with self.assertRaises(RecoveryContractError):
            self.reconcile(expected_metadata={})
