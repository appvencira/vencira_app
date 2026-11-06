"""MB1 PG17 + physical synthetic object/journal integration.

Uses a real *ephemeral test DB* ORM query, not a dump/restore. Read-only
capture while participants cooperate with an isolated POSIX file lock.
"""
import hashlib
import json
import os
import tempfile
from datetime import date
from pathlib import Path

from django.db import connection
from django.test import TransactionTestCase, override_settings
from reminders.models import Workspace, Renewal
from .models import RenewalAttachment
from .offline_multiprocess_fence_mb1 import IsolatedProcessFence
from .offline_capture_set_b18e import verify_capture_set, CaptureSetError


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class MB1PG17PhysicalCutTests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        self.tmp = tempfile.TemporaryDirectory(prefix="mb1-pg17-cut-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        os.chmod(self.root, 0o700)
        ws = Workspace.objects.create(name="MB1 SYNTHETIC")
        ren = Renewal.objects.create(
            workspace=ws, full_name="Synthetic", customer_reference="MB1-PG17",
            expires_on=date(2027, 12, 1))
        self.key = "a" * 32
        self.cipher = b"synthetic-encrypted-object"
        self.expected_cipher_sha = hashlib.sha256(self.cipher).hexdigest()
        self.journal = json.dumps({
            "version": 1, "storage_key": self.key, "state": "pending",
        }).encode()
        self.expected_journal_sha = hashlib.sha256(self.journal).hexdigest()
        self.attachment = RenewalAttachment.objects.create(
            renewal=ren, storage_key=self.key, display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=len(self.cipher),
            sha256="a" * 64, state="quarantined")
        (self.root / "object.bin").write_bytes(self.cipher)
        (self.root / "intent.json").write_bytes(self.journal)
        self.fence = IsolatedProcessFence(self.root / "fence.lock")

    def capture(self):
        with self.fence.capture():
            row = RenewalAttachment.objects.get(pk=self.attachment.pk)
            db_records = {row.storage_key.hex: {
                "cipher_sha256": self.expected_cipher_sha,
                "journal_sha256": self.expected_journal_sha,
            }}
            obj = (self.root / "object.bin").read_bytes()
            journal = (self.root / "intent.json").read_bytes()
            marker = {
                "epoch": 1, "snapshot": "mb1-pg17-physical-test",
                "inventory_sha256": hashlib.sha256(json.dumps(
                    db_records, sort_keys=True, separators=(",", ":")
                ).encode()).hexdigest()
            }
            return verify_capture_set(
                before=marker, after=marker, db_records=db_records,
                encrypted_objects={row.storage_key.hex: obj},
                journals={row.storage_key.hex: journal},
                missing_writers=(), drained=True,
            )

    def test_pg17_orm_and_files_present(self):
        result = self.capture()
        self.assertTrue(result["verified"])
        self.assertFalse(result["release_authorized"])

    def test_tampered_object_rejected(self):
        (self.root / "object.bin").write_bytes(b"tampered")
        with self.assertRaises(CaptureSetError):
            self.capture()

    def test_missing_journal_rejected(self):
        (self.root / "intent.json").unlink()
        with self.assertRaises(FileNotFoundError):
            self.capture()

    def test_missing_object_rejected(self):
        (self.root / "object.bin").unlink()
        with self.assertRaises(FileNotFoundError):
            self.capture()

    def test_cooperative_writer_lock_conflicts(self):
        from .offline_multiprocess_fence_mb1 import ProcessFenceError
        with self.fence.capture():
            with self.assertRaises(ProcessFenceError):
                with self.fence.writer(timeout=0.05):
                    pass
