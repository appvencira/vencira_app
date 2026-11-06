"""D10 synthetic inventory tests."""
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.test import TestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore, PrivateStoreError
)
from .offline_intake_journal import IntakeJournal
from .offline_inventory_d10 import inspect_inventory_d10


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class InventoryD10Tests(TestCase):

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        private = base / "private"
        records = base / "journal"
        private.mkdir(mode=0o700)
        records.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(
            private, Fernet.generate_key()
        )
        self.journal = IntakeJournal(records)

    def audit(self):
        return inspect_inventory_d10(
            journal=self.journal, store=self.store
        )

    def test_empty_inventory_is_not_release_authorization(self):
        report = self.audit()
        self.assertFalse(report["requires_review"])
        self.assertFalse(report["release_authorized"])

    def test_unregistered_physical_object_detected(self):
        key = uuid.uuid4()
        self.store.put_quarantine(key, b"D10 SYNTHETIC")
        before = (self.store.root / key.hex).read_bytes()

        report = self.audit()

        self.assertEqual(report["objects_without_intent"], 1)
        self.assertEqual(report["objects_without_metadata"], 1)
        self.assertTrue(report["requires_review"])
        self.assertEqual(
            (self.store.root / key.hex).read_bytes(), before
        )
        self.assertNotIn(key.hex, str(report))

    def test_intent_without_object_detected(self):
        import hashlib
        key = uuid.uuid4()
        self.journal.record_intent(
            key, hashlib.sha256(b"D10 SYNTHETIC").hexdigest()
        )
        report = self.audit()
        self.assertEqual(report["intents_without_object"], 1)
        self.assertTrue(report["requires_review"])

    def test_unavailable_store_fails_closed(self):
        self.store.root.rmdir()
        with self.assertRaises(PrivateStoreError):
            self.audit()

    def test_non_test_environment_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.audit()
