"""Synthetic object integrity regression tests for the split app."""
import tempfile
from datetime import date
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import TestCase

from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.models import Renewal, RenewalAttachment as Legacy, Workspace
from .models import RenewalAttachment as Independent
from .transition_object_audit import verify_encrypted_objects_readonly


class EncryptedTransitionAuditTests(TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        root.chmod(0o700)
        self.store = PrivateQuarantineStore(root, Fernet.generate_key())
        ws = Workspace.objects.create(name="synthetic-audit")
        self.renewal = Renewal.objects.create(
            workspace=ws, customer_reference="AUDIT-TEST",
            full_name="Synthetic", expires_on=date(2027, 6, 1))

    def _pair(self, payload=b"synthetic-test-only"):
        import hashlib
        old = Legacy.objects.create(
            renewal=self.renewal, display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=len(payload),
            sha256=hashlib.sha256(payload).hexdigest())
        Independent.objects.create(
            id=old.pk, renewal=self.renewal, display_name=old.display_name,
            content_type=old.content_type, byte_size=old.byte_size,
            sha256=old.sha256, storage_key=old.storage_key, state=old.state)
        return old

    def test_valid_encrypted_object_is_integrity_checked_but_never_released(self):
        old = self._pair()
        self.store.put_quarantine(old.storage_key, b"synthetic-test-only")
        report = verify_encrypted_objects_readonly(store=self.store)
        self.assertEqual((report.checked, report.unreadable,
                          report.digest_mismatches, report.size_mismatches),
                         (1, 0, 0, 0))
        self.assertFalse(report.release_authorized)

    def test_missing_encrypted_object_is_reported_without_disclosure(self):
        self._pair()
        report = verify_encrypted_objects_readonly(store=self.store)
        self.assertEqual(report.unreadable, 1)
        self.assertFalse(report.release_authorized)

    def test_metadata_mismatch_blocks_integrity_audit(self):
        old = self._pair()
        Independent.objects.filter(pk=old.pk).update(sha256="0" * 64)
        report = verify_encrypted_objects_readonly(store=self.store)
        self.assertFalse(report.metadata_aligned)
        self.assertEqual(report.checked, 0)
        self.assertFalse(report.release_authorized)

    def test_corrupt_encrypted_object_fails_integrity(self):
        old = self._pair()
        self.store.put_quarantine(old.storage_key, b"unexpected-payload")
        report = verify_encrypted_objects_readonly(store=self.store)
        self.assertTrue(report.metadata_aligned)
        self.assertEqual(report.digest_mismatches, 1)
        self.assertEqual(report.size_mismatches, 1)
        self.assertFalse(report.release_authorized)

    def test_metadata_change_during_audit_is_reported(self):
        old = self._pair()
        self.store.put_quarantine(old.storage_key, b"synthetic-test-only")
        original = self.store.read_quarantine_for_scanner_only

        def changing_read(key):
            payload = original(key)
            Independent.objects.filter(pk=old.pk).update(state="clean")
            return payload

        self.store.read_quarantine_for_scanner_only = changing_read
        report = verify_encrypted_objects_readonly(store=self.store)
        self.assertFalse(report.metadata_aligned)
        self.assertFalse(report.release_authorized)
