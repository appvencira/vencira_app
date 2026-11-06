import hashlib
import json
import uuid
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .offline_verified_restore_b09 import (
    verify_backup_set_and_restore,
)
from .offline_backup_manifest_b09 import (
    BackupManifestError, create_manifest,
)
from .offline_db_envelope_b08 import (
    DatabaseEnvelopeError, seal_database_dump,
)
from .offline_backup_contract import (
    RecoveryContractError, create_backup,
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class B09VerifiedRecoveryTests(SimpleTestCase):

    def setUp(self):
        self.snapshot = "b09-synthetic"
        self.original_db = b"PGDMP synthetic example"
        self.original_file = b"synthetic attachment"

        self.database_key = Fernet.generate_key()
        self.backup_key = Fernet.generate_key()
        self.attachment_key = Fernet.generate_key()
        self.manifest_key = b"manifest-test-key-" + b"x" * 32

        self.identifier = uuid.uuid4().hex

        cipher = Fernet(self.attachment_key).encrypt(
            self.original_file
        )

        journal = json.dumps({
            "version": 1,
            "storage_key": self.identifier,
            "sha256": sha(self.original_file),
            "state": "pending",
        }).encode()

        self.database_envelope = seal_database_dump(
            dump_bytes=self.original_db,
            key=self.database_key,
            key_id="database-v1",
            snapshot_id=self.snapshot,
        )

        self.attachment_bundle = create_backup(
            encrypted_files={
                self.identifier: cipher
            },
            journal_files={
                self.identifier + ".json": journal
            },
            backup_key=self.backup_key,
            backup_key_id="bundle-v1",
            attachment_key_id="content-v1",
            snapshot_id=self.snapshot,
        )

        self.manifest = create_manifest(
            database_envelope=self.database_envelope,
            attachment_bundle=self.attachment_bundle,
            snapshot_id=self.snapshot,
            database_key_id="database-v1",
            attachment_key_id="bundle-v1",
            manifest_key_id="manifest-v1",
            authentication_key=self.manifest_key,
        )

        self.kwargs = {
            "manifest": self.manifest,
            "database_envelope": self.database_envelope,
            "attachment_bundle": self.attachment_bundle,
            "manifest_key": self.manifest_key,
            "database_key": self.database_key,
            "backup_key": self.backup_key,
            "attachment_key": self.attachment_key,
            "snapshot_id": self.snapshot,
            "database_key_id": "database-v1",
            "attachment_bundle_key_id": "bundle-v1",
            "attachment_content_key_id": "content-v1",
            "manifest_key_id": "manifest-v1",
            "expected_database_sha256": sha(self.original_db),
            "expected_metadata": {
                self.identifier: {
                    "sha256": sha(self.original_file),
                    "byte_size": len(self.original_file),
                }
            },
            "expected_ciphertext_digests": {
                self.identifier: sha(cipher)
            },
        }

    def check(self, **changes):
        return verify_backup_set_and_restore(
            **{**self.kwargs, **changes}
        )

    def test_valid_complete_set(self):
        result = self.check()
        self.assertEqual(
            result["database_bytes"], self.original_db
        )
        self.assertEqual(result["objects"], 1)
        self.assertFalse(result["release_authorized"])

    def test_mixed_database_rejected(self):
        other = seal_database_dump(
            dump_bytes=b"another synthetic database",
            key=self.database_key,
            key_id="database-v1",
            snapshot_id=self.snapshot,
        )
        with self.assertRaises(BackupManifestError):
            self.check(database_envelope=other)

    def test_mixed_attachments_rejected(self):
        other = create_backup(
            encrypted_files={
                self.identifier: Fernet(
                    self.attachment_key
                ).encrypt(self.original_file)
            },
            journal_files={
                self.identifier + ".json": json.dumps({
                    "version": 1,
                    "storage_key": self.identifier,
                    "sha256": sha(self.original_file),
                    "state": "pending",
                }).encode()
            },
            backup_key=self.backup_key,
            backup_key_id="bundle-v1",
            attachment_key_id="content-v1",
            snapshot_id=self.snapshot,
        )
        with self.assertRaises(BackupManifestError):
            self.check(attachment_bundle=other)

    def test_wrong_manifest_key_rejected(self):
        with self.assertRaises(BackupManifestError):
            self.check(manifest_key=b"wrong-" + b"y" * 32)

    def test_wrong_database_key_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.check(database_key=Fernet.generate_key())

    def test_wrong_attachment_key_rejected(self):
        with self.assertRaises(RecoveryContractError):
            self.check(attachment_key=Fernet.generate_key())

    def test_wrong_snapshot_rejected(self):
        with self.assertRaises(BackupManifestError):
            self.check(snapshot_id="other-snapshot")

    def test_wrong_external_database_digest(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.check(expected_database_sha256="0" * 64)

    def test_wrong_external_file_metadata(self):
        with self.assertRaises(RecoveryContractError):
            self.check(expected_metadata={
                self.identifier: {
                    "sha256": "0" * 64,
                    "byte_size": len(self.original_file),
                }
            })

    def test_manifest_failure_stops_decryption(self):
        with patch(
            "renewal_attachments.offline_verified_restore_b09."
            "open_database_dump"
        ) as decoder:
            with self.assertRaises(BackupManifestError):
                self.check(
                    database_envelope=b"tampered ciphertext"
                )
            decoder.assert_not_called()

    def test_invalid_version_rejected(self):
        with self.assertRaises(BackupManifestError):
            self.check(manifest_key_id="manifest-v2")

    def test_missing_bundle_rejected(self):
        with self.assertRaises(BackupManifestError):
            self.check(attachment_bundle=b"")
