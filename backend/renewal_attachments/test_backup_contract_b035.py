import hashlib
import uuid

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .offline_backup_contract import (
    create_backup,
    inspect_backup,
    RecoveryContractError,
)


class BackupContractTests(SimpleTestCase):
    def setUp(self):
        self.identifier = uuid.uuid4().hex
        self.key = Fernet.generate_key()
        self.attachment_key = Fernet.generate_key()

        self.ciphertext = Fernet(
            self.attachment_key
        ).encrypt(b"SYNTHETIC_DOCUMENT")

        self.encrypted_files = {
            self.identifier: self.ciphertext,
        }
        self.journal_files = {
            self.identifier + ".json": b'{"state":"pending"}',
        }
        self.digests = {
            self.identifier: hashlib.sha256(
                self.ciphertext
            ).hexdigest(),
        }

        self.bundle = self.make_bundle()

    def make_bundle(self, **overrides):
        args = dict(
            encrypted_files=self.encrypted_files,
            journal_files=self.journal_files,
            backup_key=self.key,
            backup_key_id="backup-v1",
            attachment_key_id="attachment-v1",
            snapshot_id="pg17-synthetic-v1",
        )
        args.update(overrides)
        return create_backup(**args)

    def inspect(self, **overrides):
        args = dict(
            bundle=self.bundle,
            backup_key=self.key,
            expected_backup_key_id="backup-v1",
            expected_attachment_key_id="attachment-v1",
            expected_snapshot_id="pg17-synthetic-v1",
            expected_object_digests=self.digests,
        )
        args.update(overrides)
        return inspect_backup(**args)

    def test_valid_package(self):
        self.assertEqual(self.inspect()["objects"], 1)

    def test_wrong_backup_key(self):
        with self.assertRaises(RecoveryContractError):
            self.inspect(backup_key=Fernet.generate_key())

    def test_wrong_key_version(self):
        with self.assertRaises(RecoveryContractError):
            self.inspect(expected_attachment_key_id="attachment-v2")

    def test_wrong_snapshot(self):
        with self.assertRaises(RecoveryContractError):
            self.inspect(expected_snapshot_id="another-snapshot")

    def test_corrupted_package(self):
        tampered = bytearray(self.bundle)
        tampered[len(tampered)//2] ^= 1
        with self.assertRaises(RecoveryContractError):
            self.inspect(bundle=bytes(tampered))

    def test_missing_journal(self):
        with self.assertRaises(RecoveryContractError):
            self.make_bundle(journal_files={})

    def test_wrong_db_digest(self):
        with self.assertRaises(RecoveryContractError):
            self.inspect(
                expected_object_digests={
                    self.identifier: "0" * 64
                }
            )

    def test_extra_db_object(self):
        with self.assertRaises(RecoveryContractError):
            self.inspect(
                expected_object_digests={
                    **self.digests,
                    uuid.uuid4().hex: "0" * 64,
                }
            )

    def test_invalid_filename(self):
        with self.assertRaises(RecoveryContractError):
            self.make_bundle(
                encrypted_files={
                    "../unsafe": self.ciphertext,
                },
            )

    def test_no_plaintext_in_bundle(self):
        self.assertNotIn(
            b"SYNTHETIC_DOCUMENT", self.bundle
        )
