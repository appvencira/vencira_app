"""MB1 M1-02: isolated real private-store/journal interrupted-I/O states.

No live PostgreSQL, API, remote hosts, network or operational attachments.
A partial write is a synthetic file fixture, NOT a real power-loss test.
All incomplete states must fail closed and remain reviewable.
"""
import hashlib
import os
import tempfile
import uuid
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore, PrivateStoreError
from renewal_attachments.offline_intake_journal import IntakeJournal
from renewal_attachments.offline_pending_intent_reconcile_b18l import classify_pending_intent


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class MB1PartialIOFailClosedTests(SimpleTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mb1-partial-io-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.obj_root = self.root / "objects"
        self.journal_root = self.root / "journal"
        self.obj_root.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.obj_root, Fernet.generate_key())
        self.journal = IntakeJournal(str(self.journal_root))
        self.key = uuid.uuid4()
        self.payload = b"MB1_SYNTHETIC_PRIVATE_IO_OBJECT"
        self.sha = hashlib.sha256(self.payload).hexdigest()

    def _assert_blocked(self, *, journal=True, object=True, metadata=False,
                        digest=None, reason=None):
        result = classify_pending_intent(
            journal_present=journal, object_present=object,
            metadata_present=metadata, object_digest_matches=digest
        )
        if reason is not None:
            self.assertEqual(result.classification, reason)
        self.assertTrue(result.requires_manual_review)
        self.assertFalse(result.release_authorized)
        self.assertFalse(result.delete_authorized)

    def test_truncated_ciphertext_from_partial_write_is_rejected(self):
        self.journal.record_intent(self.key, self.sha)
        path = self.obj_root / self.key.hex
        path.write_bytes(self.store.fernet.encrypt(self.payload)[:24])
        path.chmod(0o600)
        with self.assertRaises(PrivateStoreError):
            self.store.read_quarantine_for_scanner_only(self.key)
        self._assert_blocked(digest=False, reason="OBJECT_DIGEST_UNVERIFIED")
        self.assertTrue(path.exists())  # no automatic deletion

    def test_incomplete_json_journal_is_rejected_and_object_preserved(self):
        self.store.put_quarantine(self.key, self.payload)
        path = self.journal_root / (self.key.hex + ".json")
        path.write_bytes(b'{"version":1,"state":"pending",')
        path.chmod(0o600)
        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(self.key)
        self.assertEqual(self.store.read_quarantine_for_scanner_only(self.key), self.payload)
        self._assert_blocked(journal=False, digest=True, reason="MISSING_JOURNAL_EVIDENCE")

    def test_journal_digest_does_not_match_valid_encrypted_object(self):
        other_sha = hashlib.sha256(b"DIFFERENT").hexdigest()
        self.journal.record_intent(self.key, other_sha)
        self.store.put_quarantine(self.key, self.payload)
        self.assertNotEqual(
            self.journal.read_intent(self.key)["sha256"],
            hashlib.sha256(self.store.read_quarantine_for_scanner_only(self.key)).hexdigest()
        )
        self._assert_blocked(digest=False, reason="OBJECT_DIGEST_UNVERIFIED")

    def test_durable_pair_without_committed_metadata_requires_review(self):
        self.journal.record_intent(self.key, self.sha)
        self.store.put_quarantine(self.key, self.payload)
        self.assertEqual(self.store.read_quarantine_for_scanner_only(self.key), self.payload)
        self._assert_blocked(digest=True, reason="ORPHAN_ENCRYPTED_OBJECT")

    def test_encrypted_object_fsync_failure_cleans_uncommitted_object(self):
        self.journal.record_intent(self.key, self.sha)
        with patch("reminders.attachment_private_store.os.fsync",
                   side_effect=OSError("synthetic ENOSPC/fsync")):
            with self.assertRaises(PrivateStoreError):
                self.store.put_quarantine(self.key, self.payload)
        self.assertFalse((self.obj_root / self.key.hex).exists())
        self.assertTrue((self.journal_root / (self.key.hex + ".json")).exists())
        self._assert_blocked(object=False, reason="ORPHAN_PENDING_INTENT")

    def test_journal_fsync_failure_remains_uncommitted_and_requires_review(self):
        with patch("renewal_attachments.offline_intake_journal.os.fsync",
                   side_effect=OSError("synthetic fsync failure")):
            with self.assertRaises(PrivateStoreError):
                self.journal.record_intent(self.key, self.sha)
        # The file may remain after failed fsync; it is NOT committed evidence.
        self.assertTrue((self.journal_root / (self.key.hex + ".json")).exists())
        self.assertFalse((self.obj_root / self.key.hex).exists())
        self._assert_blocked(object=False, reason="ORPHAN_PENDING_INTENT")

    def test_copying_journal_under_wrong_uuid_cannot_be_accepted(self):
        self.journal.record_intent(self.key, self.sha)
        other = uuid.uuid4()
        source = self.journal_root / (self.key.hex + ".json")
        (self.journal_root / (other.hex + ".json")).write_bytes(source.read_bytes())
        with self.assertRaises(PrivateStoreError):
            self.journal.read_intent(other)
        self._assert_blocked(journal=False, object=False,
                             reason="MISSING_JOURNAL_EVIDENCE")

    def test_missing_journal_with_valid_object_requires_review(self):
        self.store.put_quarantine(self.key, self.payload)
        self._assert_blocked(journal=False, digest=True,
                             reason="MISSING_JOURNAL_EVIDENCE")
        self.assertTrue((self.obj_root / self.key.hex).exists())
