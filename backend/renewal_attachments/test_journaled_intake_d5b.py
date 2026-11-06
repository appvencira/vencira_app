"""D5B synthetic offline journal integration tests."""
import tempfile
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore, PrivateStoreError,
)
from reminders.attachment_quarantine_intake import stage_private_attachment
from .offline_intake_journal import IntakeJournal

PDF = b"%PDF-1.4\nSynthetic document\n%%EOF"


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class JournaledIntakeD5BTests(SimpleTestCase):

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.private = base / "private"
        self.journal_root = base / "journal"
        self.private.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(
            self.private, Fernet.generate_key()
        )
        self.journal = IntakeJournal(self.journal_root)

    def stage(self, callback):
        return stage_private_attachment(
            store=self.store,
            filename="synthetic.pdf",
            content_type="application/pdf",
            content=PDF,
            create_metadata=callback,
            journal=self.journal,
        )

    def test_intent_precedes_storage(self):
        original = self.store.put_quarantine

        def intercepted(key, payload):
            self.assertEqual(
                self.journal.read_intent(key)["state"], "pending"
            )
            return original(key, payload)

        with patch.object(
            self.store, "put_quarantine", side_effect=intercepted
        ):
            item = self.stage(lambda staged: staged)

        self.assertTrue((self.private / item.storage_key.hex).exists())

    def test_metadata_failure_preserves_pending_intent(self):
        keys = []

        def fail(staged):
            keys.append(staged.storage_key)
            raise RuntimeError("SYNTHETIC_METADATA_FAILURE")

        with self.assertRaises(RuntimeError):
            self.stage(fail)

        self.assertEqual(list(self.private.iterdir()), [])
        self.assertEqual(
            self.journal.read_intent(keys[0])["state"], "pending"
        )

    def test_storage_failure_retains_intent(self):
        with patch.object(
            self.store, "put_quarantine",
            side_effect=PrivateStoreError("SYNTHETIC_STORAGE_FAILURE"),
        ):
            with self.assertRaises(PrivateStoreError):
                self.stage(lambda staged: staged)

        self.assertEqual(list(self.private.iterdir()), [])
        self.assertEqual(len(list(self.journal_root.iterdir())), 1)

    def test_journal_failure_blocks_storage(self):
        with patch.object(
            self.journal, "record_intent",
            side_effect=PrivateStoreError("SYNTHETIC_JOURNAL_FAILURE"),
        ):
            with self.assertRaises(PrivateStoreError):
                self.stage(lambda staged: staged)

        self.assertEqual(list(self.private.iterdir()), [])
