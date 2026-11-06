"""MB1 synthetic interruption contracts for offline attachment staging.

No Django database, API, network or production storage. Tests intentionally
document the orphan-intent gap on a failed object write.
"""
import unittest
from unittest.mock import Mock, patch

from reminders.attachment_quarantine_intake import stage_private_attachment


class MB1IntakeFailureContract(unittest.TestCase):
    def setUp(self):
        self.store = Mock()
        self.journal = Mock()
        self.payload = b"%PDF-1.4\nMB1 synthetic interruption test\n"
        self.args = dict(
            store=self.store, journal=self.journal,
            filename="test.pdf", content_type="application/pdf",
            content=self.payload,
        )

    def test_success_creates_intent_then_object_then_metadata(self):
        events = []
        self.journal.record_intent.side_effect = lambda *args: events.append("intent")
        self.store.put_quarantine.side_effect = lambda *args: events.append("object")
        result = stage_private_attachment(
            **self.args,
            create_metadata=lambda staged: (events.append("metadata"), object())[1],
        )
        self.assertIsNotNone(result)
        self.assertEqual(events, ["intent", "object", "metadata"])
        self.store.discard_quarantine.assert_not_called()

    def test_intent_failure_cannot_write_object_or_metadata(self):
        self.journal.record_intent.side_effect = OSError("synthetic failed intent")
        metadata = Mock()
        with self.assertRaises(OSError):
            stage_private_attachment(**self.args, create_metadata=metadata)
        self.store.put_quarantine.assert_not_called()
        metadata.assert_not_called()

    def test_object_failure_leaves_intent_for_reconciliation(self):
        self.store.put_quarantine.side_effect = OSError("synthetic disk full")
        metadata = Mock()
        with self.assertRaises(OSError):
            stage_private_attachment(**self.args, create_metadata=metadata)
        self.journal.record_intent.assert_called_once()
        metadata.assert_not_called()
        # Intent was written before object; a separate recovery routine must
        # classify and reconcile it. This is NOT an atomic transaction.
        self.store.discard_quarantine.assert_not_called()

    def test_metadata_exception_preserves_private_object_for_reconciliation(self):
        metadata = Mock(side_effect=RuntimeError("synthetic PostgreSQL reject"))
        with self.assertRaises(RuntimeError):
            stage_private_attachment(**self.args, create_metadata=metadata)
        self.store.discard_quarantine.assert_not_called()
        self.journal.record_intent.assert_called_once()

    def test_missing_metadata_preserves_object_instead_of_assuming_rollback(self):
        with self.assertRaises(Exception):
            stage_private_attachment(**self.args, create_metadata=lambda _: None)
        self.store.discard_quarantine.assert_not_called()

    def test_committed_metadata_with_lost_ack_never_triggers_destructive_cleanup(self):
        committed = []
        def commit_then_timeout(staged):
            committed.append(staged.storage_key)
            raise TimeoutError("synthetic post-commit lost acknowledgement")
        with self.assertRaises(TimeoutError):
            stage_private_attachment(
                **self.args, create_metadata=commit_then_timeout
            )
        self.assertEqual(len(committed), 1)
        self.journal.record_intent.assert_called_once()
        self.store.discard_quarantine.assert_not_called()


if __name__ == "__main__":
    unittest.main()
