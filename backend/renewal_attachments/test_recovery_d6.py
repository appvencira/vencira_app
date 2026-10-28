"""D6A: clasificación con objetos sintéticos."""
import hashlib
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from .offline_intake_journal import IntakeJournal
from .offline_recovery_d6 import classify_object


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class RecoveryD6Tests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

        base = Path(self.tmp.name)
        self.root = base / "private"
        journal_root = base / "journal"
        self.root.mkdir(mode=0o700)
        journal_root.mkdir(mode=0o700)

        self.store = PrivateQuarantineStore(
            self.root, Fernet.generate_key()
        )
        self.journal = IntakeJournal(journal_root)
        self.key = uuid.uuid4()

        self.payload = b"D6 synthetic only"
        self.journal.record_intent(
            self.key,
            hashlib.sha256(self.payload).hexdigest(),
        )

    def classify(self):
        return classify_object(
            journal=self.journal,
            store=self.store,
            key=self.key,
        )

    def test_verified(self):
        self.store.put_quarantine(self.key, self.payload)
        self.assertEqual(self.classify(), "verified")

    def test_missing_object(self):
        self.assertEqual(self.classify(), "missing")

    def test_missing_volume(self):
        self.root.rmdir()
        self.assertEqual(self.classify(), "unavailable")

    def test_corrupt_object(self):
        self.store.put_quarantine(self.key, b"changed content")
        self.assertEqual(self.classify(), "invalid")

    def test_no_mutations(self):
        self.store.put_quarantine(self.key, self.payload)
        path = self.root / self.key.hex
        before = path.read_bytes()

        self.classify()

        self.assertEqual(path.read_bytes(), before)
        self.assertFalse(
            self.journal.read_intent(self.key).get(
                "release_authorized", False
            )
        )
