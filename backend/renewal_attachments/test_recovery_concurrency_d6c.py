"""D6C: concurrent read-only evaluation on synthetic quarantine."""
import hashlib
import tempfile
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from .offline_intake_journal import IntakeJournal
from .offline_recovery_d6 import classify_object
from .offline_recovery_policy_d6 import decide_recovery, retry_decision


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class RecoveryConcurrencyD6CTests(SimpleTestCase):

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        private = base / "private"
        journal_dir = base / "journal"
        private.mkdir(mode=0o700)
        journal_dir.mkdir(mode=0o700)

        self.store = PrivateQuarantineStore(
            private, Fernet.generate_key()
        )
        self.journal = IntakeJournal(journal_dir)
        self.key = uuid.uuid4()
        self.content = b"D6C synthetic concurrent evaluation"
        self.journal.record_intent(
            self.key, hashlib.sha256(self.content).hexdigest()
        )
        self.store.put_quarantine(self.key, self.content)
        self.object_path = private / self.key.hex
        self.intent_path = journal_dir / (self.key.hex + ".json")

    def evaluate(self, _):
        state = classify_object(
            journal=self.journal, store=self.store, key=self.key
        )
        return decide_recovery(state)

    def test_concurrent_evaluations_remain_fail_closed(self):
        original_object = self.object_path.read_bytes()
        original_intent = self.intent_path.read_bytes()

        with ThreadPoolExecutor(max_workers=8) as executor:
            results = list(executor.map(self.evaluate, range(40)))

        self.assertEqual(len(results), 40)
        self.assertTrue(all(
            result.classification == "verified"
            and result.action == "reconcile_metadata"
            and not result.terminal
            and not result.release_authorized
            for result in results
        ))
        self.assertEqual(self.object_path.read_bytes(), original_object)
        self.assertEqual(self.intent_path.read_bytes(), original_intent)

    def test_repeated_decision_cannot_grant_access(self):
        decision = decide_recovery("unavailable")
        for _ in range(100):
            decision = retry_decision(decision, "verified")
            self.assertFalse(decision.release_authorized)
            self.assertFalse(decision.terminal)
        self.assertEqual(decision.action, "reconcile_metadata")
