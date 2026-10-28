import tempfile
from pathlib import Path
from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .attachment_private_store import PrivateQuarantineStore
from .attachment_quarantine_intake import stage_private_attachment


class StagedIntakeTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "private"
        self.root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.root, Fernet.generate_key())
        self.pdf = b"%PDF-1.7\nsynthetic\n%%EOF"

    def stage(self, callback):
        return stage_private_attachment(
            store=self.store, filename="fictional.pdf",
            content_type="application/pdf", content=self.pdf,
            create_metadata=callback)

    def test_encrypted_staged_content_with_quarantine_only_state(self):
        staged = self.stage(lambda metadata: metadata)
        self.assertEqual(staged.state, "quarantined")
        self.assertFalse(staged.download_allowed)
        self.assertEqual(staged.byte_size, len(self.pdf))
        self.assertNotIn(self.pdf, (self.root / staged.storage_key.hex).read_bytes())
        self.assertEqual(self.store.read_quarantine_for_scanner_only(
            staged.storage_key), self.pdf)

    def test_metadata_failure_removes_orphan(self):
        def fail(metadata):
            raise ValueError("simulated DB failure")
        with self.assertRaises(ValueError):
            self.stage(fail)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_missing_metadata_removes_orphan(self):
        with self.assertRaises(Exception):
            self.stage(lambda metadata: None)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_invalid_content_never_writes(self):
        with self.assertRaises(ValueError):
            stage_private_attachment(
                store=self.store, filename="../invalid.pdf",
                content_type="application/pdf", content=self.pdf,
                create_metadata=lambda metadata: metadata)
        self.assertEqual(list(self.root.iterdir()), [])
