"""D10B: ensayos de corrupción del diario, sin datos reales."""
import hashlib
import json
import os
import tempfile
import uuid
from pathlib import Path

from django.core.exceptions import PermissionDenied
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateStoreError
from .offline_intake_journal import IntakeJournal


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class JournalResilienceD10B(SimpleTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "journal"
        self.root.mkdir(mode=0o700)
        self.journal = IntakeJournal(self.root)
        self.key = uuid.uuid4()
        self.digest = hashlib.sha256(b"SYNTHETIC").hexdigest()

    def path(self):
        return self.root / (self.key.hex + ".json")

    def test_valid_intent_survives_reopening(self):
        self.journal.record_intent(self.key, self.digest)
        reopened = IntakeJournal(self.root)
        self.assertEqual(
            reopened.read_intent(self.key)["sha256"],
            self.digest,
        )

    def test_truncated_intent_fails_closed(self):
        self.path().write_bytes(b'{"version":1')
        os.chmod(self.path(), 0o600)
        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(self.key)

    def test_duplicate_cannot_overwrite(self):
        self.journal.record_intent(self.key, self.digest)
        original = self.path().read_bytes()
        with self.assertRaises(PrivateStoreError):
            self.journal.record_intent(
                self.key, "f" * 64
            )
        self.assertEqual(self.path().read_bytes(), original)

    def test_symlink_is_rejected(self):
        target = self.root.parent / "target"
        target.write_text("SYNTHETIC")
        self.path().symlink_to(target)
        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(self.key)
        self.assertEqual(target.read_text(), "SYNTHETIC")

    def test_oversized_record_is_rejected(self):
        self.path().write_bytes(b"x" * 2048)
        os.chmod(self.path(), 0o600)
        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(self.key)

    def test_production_access_is_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.journal.record_intent(self.key, self.digest)
