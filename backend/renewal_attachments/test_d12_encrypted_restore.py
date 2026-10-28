"""D12: ensayo sintético de recuperación cifrada.

No configura respaldos operativos ni utiliza datos de clientes.
"""
import hashlib
import os
import shutil
import tempfile
import uuid
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore, PrivateStoreError
)
from .offline_intake_journal import IntakeJournal


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D12EncryptedRestoreTests(SimpleTestCase):

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)

        self.base = Path(tmp.name)
        self.original = self.base / "original"
        self.original.mkdir(mode=0o700)

        self.private = self.original / "private"
        self.records = self.original / "journal"

        self.private.mkdir(mode=0o700)
        self.records.mkdir(mode=0o700)

        self.key = Fernet.generate_key()
        self.object_id = uuid.uuid4()
        self.content = b"%PDF-1.4\nD12 synthetic\n%%EOF"

        self.store = PrivateQuarantineStore(
            self.private, self.key
        )
        self.journal = IntakeJournal(self.records)

    def stage(self):
        self.journal.record_intent(
            self.object_id,
            hashlib.sha256(self.content).hexdigest(),
        )
        self.store.put_quarantine(
            self.object_id, self.content
        )

    def restore(self):
        recovered = self.base / "restored"
        shutil.copytree(self.original, recovered)

        store = PrivateQuarantineStore(
            recovered / "private", self.key
        )
        journal = IntakeJournal(
            recovered / "journal"
        )
        return store, journal

    def test_reopen_encrypted_object_and_intent(self):
        self.stage()

        store, journal = self.restore()
        intent = journal.read_intent(self.object_id)
        content = store.read_quarantine_for_scanner_only(
            self.object_id
        )

        self.assertEqual(
            intent["sha256"],
            hashlib.sha256(content).hexdigest(),
        )
        self.assertEqual(content, self.content)

    def test_ciphertext_not_plaintext(self):
        self.stage()
        ciphertext = (
            self.private / self.object_id.hex
        ).read_bytes()

        self.assertNotEqual(ciphertext, self.content)
        self.assertNotIn(self.content, ciphertext)

    def test_wrong_key_fails_closed(self):
        self.stage()
        self.restore()

        recovered = self.base / "restored"
        wrong_store = PrivateQuarantineStore(
            recovered / "private", Fernet.generate_key()
        )

        with self.assertRaises(PrivateStoreError):
            wrong_store.read_quarantine_for_scanner_only(
                self.object_id
            )

    def test_missing_ciphertext_fails_closed(self):
        self.stage()
        store, journal = self.restore()

        (store.root / self.object_id.hex).unlink()
        self.assertIsNotNone(
            journal.read_intent(self.object_id)
        )

        with self.assertRaises(PrivateStoreError):
            store.read_quarantine_for_scanner_only(
                self.object_id
            )

    def test_directory_fsync_after_file_fsync(self):
        actual_fsync = os.fsync

        with patch(
            "reminders.attachment_private_store.os.fsync",
            wraps=actual_fsync,
        ) as mocked:
            self.store.put_quarantine(
                self.object_id, self.content
            )

        self.assertGreaterEqual(mocked.call_count, 2)
        self.assertEqual(
            self.store.read_quarantine_for_scanner_only(
                self.object_id
            ),
            self.content,
        )
