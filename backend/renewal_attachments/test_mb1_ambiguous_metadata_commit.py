"""M1-02: real private Fernet + durable journal during ambiguous metadata commit.

The SQL writer is a simulated acknowledgement boundary: these tests do not
claim a live PG17 network/transaction test or operational reconciliation.
"""
import hashlib
import tempfile
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore, PrivateStoreError
from reminders.attachment_quarantine_intake import stage_private_attachment
from renewal_attachments.offline_intake_journal import IntakeJournal
from renewal_attachments.offline_pending_intent_reconcile_b18l import classify_pending_intent


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class M102AmbiguousMetadataAckTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="mb1-ambiguous-metadata-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.obj_root = self.root / "objects"
        self.journal_root = self.root / "journal"
        self.obj_root.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.obj_root, Fernet.generate_key())
        self.journal = IntakeJournal(str(self.journal_root))
        self.content = b"%PDF-1.7\nM1-02_SYNTHETIC_COMMIT_ACK\n%%EOF"
        self.committed = set()
        self.staged_key = None

    def stage(self, callback, *, journal=True):
        def observe(staged):
            self.staged_key = staged.storage_key
            return callback(staged)
        return stage_private_attachment(
            store=self.store,
            journal=self.journal if journal else None,
            filename="synthetic.pdf", content_type="application/pdf",
            content=self.content, create_metadata=observe,
        )

    def assert_cipher_preserved(self, key, *, journal_present):
        stored = (self.obj_root / key.hex)
        self.assertTrue(stored.exists())
        self.assertNotIn(self.content, stored.read_bytes())
        self.assertEqual(self.store.read_quarantine_for_scanner_only(key), self.content)
        if journal_present:
            self.assertEqual(self.journal.read_intent(key)["sha256"],
                             hashlib.sha256(self.content).hexdigest())
        else:
            self.assertFalse((self.journal_root / (key.hex + ".json")).exists())

    def test_commit_then_ack_timeout_keeps_committed_referenced_cipher_and_intent(self):
        def commit_then_fail(staged):
            self.committed.add(staged.storage_key)
            raise TimeoutError("synthetic acknowledged SQL commit lost")
        with self.assertRaises(TimeoutError):
            self.stage(commit_then_fail)
        key = self.staged_key
        self.assertIn(key, self.committed)
        self.assert_cipher_preserved(key, journal_present=True)
        decision = classify_pending_intent(
            journal_present=True, object_present=True,
            metadata_present=True, object_digest_matches=True,
        )
        self.assertEqual(decision.classification, "PENDING_INTENT_WITH_COMPLETE_PAIR")
        self.assertTrue(decision.requires_manual_review)
        self.assertFalse(decision.delete_authorized)
        self.assertFalse(decision.release_authorized)

    def test_before_commit_error_keeps_encrypted_orphan_for_readonly_review(self):
        def fail_before_commit(staged):
            raise RuntimeError("synthetic SQL rollback")
        with self.assertRaises(RuntimeError):
            self.stage(fail_before_commit)
        key = self.staged_key
        self.assertNotIn(key, self.committed)
        self.assert_cipher_preserved(key, journal_present=True)
        decision = classify_pending_intent(
            journal_present=True, object_present=True,
            metadata_present=False, object_digest_matches=True,
        )
        self.assertEqual(decision.classification, "ORPHAN_ENCRYPTED_OBJECT")
        self.assertFalse(decision.release_authorized)
        self.assertFalse(decision.delete_authorized)

    def test_missing_ack_without_journal_keeps_cipher_but_blocks_release(self):
        with self.assertRaises(TimeoutError):
            self.stage(lambda staged: (_ for _ in ()).throw(TimeoutError()), journal=False)
        self.assert_cipher_preserved(self.staged_key, journal_present=False)
        decision = classify_pending_intent(
            journal_present=False, object_present=True,
            metadata_present=False, object_digest_matches=True,
        )
        self.assertEqual(decision.classification, "MISSING_JOURNAL_EVIDENCE")
        self.assertFalse(decision.release_authorized)
        self.assertFalse(decision.delete_authorized)

    def test_no_metadata_ack_response_preserves_evidence(self):
        with self.assertRaises(PrivateStoreError):
            self.stage(lambda staged: None)
        self.assert_cipher_preserved(self.staged_key, journal_present=True)
        self.assertFalse((self.obj_root / self.staged_key.hex).is_symlink())
