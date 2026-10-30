"""MB1: real SIGKILL interruption after durable journal/object writes.

Only synthetic disposable directories; no PostgreSQL and no live service.
"""
import hashlib
import os
import signal
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path

from cryptography.fernet import Fernet

from .offline_recovery_classifier_mb1 import classify_recovery_inventory


class MB1KilledWriterTests(unittest.TestCase):
    def test_sigkill_after_durable_intent_and_after_object(self):
        from django.test import override_settings
        with override_settings(
            VENCIRA_ENV="test",
            VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
        ):
            for stage in ("intent", "object"):
                with self.subTest(stage=stage), tempfile.TemporaryDirectory() as tmp:
                    obj = Path(tmp) / "obj"
                    journal = Path(tmp) / "journal"
                    obj.mkdir(mode=0o700)
                    journal.mkdir(mode=0o700)
                    key = uuid.uuid4()
                    fernet_key = Fernet.generate_key().decode("ascii")
                    script = """
import hashlib, os, signal, uuid
from pathlib import Path
from renewal_attachments.offline_intake_journal import IntakeJournal
from reminders.attachment_private_store import PrivateQuarantineStore
payload=b'MB1_REAL_SIGKILL_SYNTHETIC'
key=uuid.UUID(hex=os.environ['MB1_KEY'])
journal=IntakeJournal(os.environ['MB1_JOURNAL'])
journal.record_intent(key, hashlib.sha256(payload).hexdigest())
if os.environ['MB1_STAGE']=='object':
    store=PrivateQuarantineStore(Path(os.environ['MB1_OBJECTS']), os.environ['MB1_FERNET'].encode())
    store.put_quarantine(key, payload)
os.kill(os.getpid(), signal.SIGKILL)
"""
                    env = os.environ.copy()
                    env.update(
                        VENCIRA_ENV="test",
                        VENCIRA_ATTACHMENT_SPLIT_REHEARSAL="1",
                        MB1_KEY=key.hex,
                        MB1_JOURNAL=str(journal),
                        MB1_OBJECTS=str(obj),
                        MB1_STAGE=stage,
                        MB1_FERNET=fernet_key,
                    )
                    proc = subprocess.run(
                        [sys.executable, "-c", script],
                        env=env, capture_output=True, check=False, timeout=20,
                    )
                    self.assertEqual(proc.returncode, -signal.SIGKILL, proc.stderr)
                    self.assertTrue((journal / (key.hex + ".json")).is_file())
                    objects = {uuid.UUID(hex=p.name) for p in obj.iterdir()}
                    intents = {uuid.UUID(hex=p.stem) for p in journal.iterdir()}
                    report = classify_recovery_inventory(
                        intents=intents, objects=objects, metadata=set(),
                    )
                    if stage == "intent":
                        self.assertEqual(report["intent_only"], 1)
                        self.assertEqual(report["intent_and_object_without_metadata"], 0)
                    else:
                        self.assertEqual(report["intent_and_object_without_metadata"], 1)
                        self.assertEqual(report["intent_only"], 0)
                    self.assertTrue(report["requires_review"])
                    self.assertFalse(report["repair_authorized"])
                    self.assertFalse(report["deletion_authorized"])
                    self.assertFalse(report["release_authorized"])
