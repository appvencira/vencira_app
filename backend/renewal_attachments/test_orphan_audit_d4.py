"""Pruebas D4 con archivos y datos exclusivamente sintéticos."""
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.test import TestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore,
    PrivateStoreError,
)
from .offline_orphan_audit import inspect_orphan_quarantine


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class OrphanAuditD4Tests(TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "private"
        self.root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(
            self.root, Fernet.generate_key()
        )

    def test_empty_store_is_consistent_but_not_authorized(self):
        report = inspect_orphan_quarantine(store=self.store)
        self.assertTrue(report["consistent"])
        self.assertEqual(report["orphan_count"], 0)
        self.assertFalse(report["release_authorized"])

    def test_orphan_is_detected_without_deletion(self):
        key = uuid.uuid4()
        self.store.put_quarantine(key, b"synthetic-content")
        before = (self.root / key.hex).read_bytes()

        report = inspect_orphan_quarantine(store=self.store)

        self.assertEqual(report["orphan_count"], 1)
        self.assertFalse(report["consistent"])
        self.assertEqual((self.root / key.hex).read_bytes(), before)
        self.assertNotIn(key.hex, str(report))

    def test_missing_root_fails_closed(self):
        self.root.rmdir()
        with self.assertRaises(PrivateStoreError):
            inspect_orphan_quarantine(store=self.store)

    def test_production_environment_is_rejected(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                inspect_orphan_quarantine(store=self.store)
