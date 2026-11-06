"""D3 rehearsal: metadata and physical cleanup failures must not be mistaken for success.

Synthetic inputs, no HTTP endpoint, no live database or persistent storage.
"""
import tempfile
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from reminders.attachment_private_store import PrivateQuarantineStore, PrivateStoreError
from reminders.attachment_quarantine_intake import stage_private_attachment


PDF = b"%PDF-1.4\nsynthetic D3\n%%EOF"


class DoubleFailureTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "private"
        self.root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.root, Fernet.generate_key())

    def intake(self):
        def fail_metadata(_staged):
            raise RuntimeError("D3_SYNTHETIC_METADATA_FAILURE")
        return stage_private_attachment(
            store=self.store, filename="synthetic.pdf",
            content_type="application/pdf", content=PDF,
            create_metadata=fail_metadata,
        )

    def test_metadata_failure_removes_encrypted_object(self):
        with self.assertRaisesRegex(RuntimeError, "D3_SYNTHETIC_METADATA_FAILURE"):
            self.intake()
        self.assertEqual(list(self.root.iterdir()), [])

    def test_double_failure_keeps_orphan_encrypted_and_raises(self):
        with patch.object(self.store, "discard_quarantine",
                          side_effect=PrivateStoreError("D3_SYNTHETIC_CLEANUP_FAILURE")):
            with self.assertRaisesRegex(
                PrivateStoreError, "D3_SYNTHETIC_CLEANUP_FAILURE"
            ) as error:
                self.intake()

        self.assertIsInstance(error.exception.__context__, RuntimeError)
        objects = list(self.root.iterdir())
        self.assertEqual(len(objects), 1)
        self.assertNotIn(PDF, objects[0].read_bytes())
        self.assertEqual(objects[0].stat().st_mode & 0o077, 0)
        # Deliberately *not* claiming recovery: orphan still exists and
        # needs an authenticated, auditable reconciliation workflow.
