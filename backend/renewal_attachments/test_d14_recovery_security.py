"""D14: recuperación y rechazo de datos inconsistentes.

Solo pruebas sintéticas. No activa adjuntos reales ni endpoints.
"""
import hashlib
import os
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore,
    PrivateStoreError,
)
from .offline_intake_journal import IntakeJournal


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D14RecoverySecurityTests(SimpleTestCase):

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)

        self.root = Path(temp.name)
        self.files = self.root / "files"
        self.journal_dir = self.root / "journal"

        self.files.mkdir(mode=0o700)
        self.journal_dir.mkdir(mode=0o700)

        self.key = Fernet.generate_key()
        self.identifier = uuid.uuid4()
        self.content = b"D14 SYNTHETIC CONTROL"

        self.store = PrivateQuarantineStore(
            self.files, self.key
        )
        self.journal = IntakeJournal(self.journal_dir)

    def stage(self):
        self.journal.record_intent(
            self.identifier,
            hashlib.sha256(self.content).hexdigest(),
        )
        self.store.put_quarantine(
            self.identifier, self.content
        )

    def test_ciphertext_tampering_rejected(self):
        self.stage()

        path = self.files / self.identifier.hex
        data = bytearray(path.read_bytes())
        data[len(data) // 2] ^= 1
        path.write_bytes(data)

        with self.assertRaises(PrivateStoreError):
            self.store.read_quarantine_for_scanner_only(
                self.identifier
            )

    def test_truncated_ciphertext_rejected(self):
        self.stage()

        path = self.files / self.identifier.hex
        path.write_bytes(path.read_bytes()[:12])

        with self.assertRaises(PrivateStoreError):
            self.store.read_quarantine_for_scanner_only(
                self.identifier
            )

    def test_key_rotation_without_old_key_fails_closed(self):
        self.stage()

        new_key = Fernet.generate_key()
        new_store = PrivateQuarantineStore(
            self.files, new_key
        )

        with self.assertRaises(PrivateStoreError):
            new_store.read_quarantine_for_scanner_only(
                self.identifier
            )

        old_store = PrivateQuarantineStore(
            self.files, self.key
        )
        self.assertEqual(
            old_store.read_quarantine_for_scanner_only(
                self.identifier
            ),
            self.content,
        )

    def test_missing_journal_rejected(self):
        self.stage()

        (
            self.journal_dir /
            (self.identifier.hex + ".json")
        ).unlink()

        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(self.identifier)

    def test_journal_hash_mismatch_detectable(self):
        self.stage()

        intent = self.journal.read_intent(self.identifier)
        received = self.store.read_quarantine_for_scanner_only(
            self.identifier
        )

        self.assertEqual(
            hashlib.sha256(received).hexdigest(),
            intent["sha256"],
        )

        altered = received + b" altered"
        self.assertNotEqual(
            hashlib.sha256(altered).hexdigest(),
            intent["sha256"],
        )

    def test_insecure_directory_rejected(self):
        original_mode = self.files.stat().st_mode & 0o777
        try:
            os.chmod(self.files, 0o755)
            with self.assertRaises(PrivateStoreError):
                PrivateQuarantineStore(
                    self.files, self.key
                )
        finally:
            os.chmod(self.files, original_mode)

    def test_reusing_object_identifier_rejected(self):
        self.store.put_quarantine(
            self.identifier, self.content
        )

        with self.assertRaises(PrivateStoreError):
            self.store.put_quarantine(
                self.identifier, b"replacement"
            )

        self.assertEqual(
            self.store.read_quarantine_for_scanner_only(
                self.identifier
            ),
            self.content,
        )
