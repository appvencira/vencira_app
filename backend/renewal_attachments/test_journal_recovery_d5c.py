"""D5C: comprobaciones sintéticas posteriores a reinicio."""
import hashlib
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from .offline_intake_journal import IntakeJournal
from .offline_journal_recovery import inspect_pending_intents


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class JournalRecoveryTests(SimpleTestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

        root = Path(self.tmp.name)
        self.private = root / "private"
        self.journal_root = root / "journal"
        self.private.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)
        self.key = Fernet.generate_key()

        self.store = PrivateQuarantineStore(
            self.private, self.key
        )
        self.journal = IntakeJournal(self.journal_root)

    def create_intent(self, content, write_object=True):
        key = uuid.uuid4()
        self.journal.record_intent(
            key, hashlib.sha256(content).hexdigest()
        )
        if write_object:
            self.store.put_quarantine(key, content)
        return key

    def recover(self):
        # Simula reconstruir los objetos de acceso tras reinicio.
        journal = IntakeJournal(self.journal_root)
        store = PrivateQuarantineStore(self.private, self.key)
        return inspect_pending_intents(
            journal=journal, store=store
        )

    def test_empty_journal(self):
        report = self.recover()
        self.assertEqual(report["pending_total"], 0)
        self.assertFalse(report["release_authorized"])

    def test_valid_encrypted_object_after_restart(self):
        self.create_intent(b"D5C synthetic verified")
        report = self.recover()
        self.assertEqual(report["verified_object"], 1)
        self.assertEqual(report["invalid_object"], 0)
        self.assertFalse(report["release_authorized"])

    def test_pending_intent_without_file(self):
        self.create_intent(b"D5C synthetic absent", False)
        report = self.recover()
        self.assertEqual(report["pending_total"], 1)
        self.assertEqual(report["invalid_object"], 1)

    def test_digest_mismatch_is_detected(self):
        key = self.create_intent(b"D5C original", False)
        self.store.put_quarantine(key, b"D5C altered")
        report = self.recover()
        self.assertEqual(report["verified_object"], 0)
        self.assertEqual(report["invalid_object"], 1)

    def test_audit_does_not_delete_objects_or_intents(self):
        key = self.create_intent(b"D5C preserve")
        before = (self.private / key.hex).read_bytes()

        self.recover()

        self.assertEqual(
            (self.private / key.hex).read_bytes(), before
        )
        self.assertTrue(
            (self.journal_root / (key.hex + ".json")).exists()
        )
