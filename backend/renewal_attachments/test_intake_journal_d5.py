"""D5A: persistencia y fallos cerrados con datos sintéticos."""
import hashlib
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
class IntakeJournalD5Tests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "journal"
        self.root.mkdir(mode=0o700)
        self.journal = IntakeJournal(self.root)
        self.key = uuid.uuid4()
        self.digest = hashlib.sha256(b"D5 synthetic").hexdigest()

    def test_intent_survives_new_instance(self):
        self.journal.record_intent(self.key, self.digest)
        restarted = IntakeJournal(self.root)
        result = restarted.read_intent(self.key)
        self.assertEqual(result["storage_key"], self.key.hex)
        self.assertEqual(result["sha256"], self.digest)
        self.assertEqual(result["state"], "pending")

    def test_duplicate_intent_fails_without_overwrite(self):
        self.journal.record_intent(self.key, self.digest)
        original = (self.root / (self.key.hex + ".json")).read_bytes()
        with self.assertRaises(PrivateStoreError):
            self.journal.record_intent(self.key, self.digest)
        self.assertEqual(
            (self.root / (self.key.hex + ".json")).read_bytes(),
            original,
        )

    def test_missing_journal_root_fails_closed(self):
        self.root.rmdir()
        with self.assertRaises(PrivateStoreError):
            self.journal.record_intent(self.key, self.digest)

    def test_production_environment_is_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.journal.record_intent(self.key, self.digest)

    def test_invalid_digest_is_rejected(self):
        with self.assertRaises(PrivateStoreError):
            self.journal.record_intent(self.key, "invalid")
        self.assertEqual(list(self.root.iterdir()), [])
