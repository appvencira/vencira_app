import os
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .attachment_orphan_audit import audit_private_quarantine
from .attachment_private_store import PrivateQuarantineStore, PrivateStoreError


class QuarantineOrphanAuditTests(SimpleTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "quarantine"
        self.root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.root, Fernet.generate_key())

    def test_reference_orphan_and_missing_are_only_reported(self):
        linked = uuid.uuid4()
        orphan = uuid.uuid4()
        missing = uuid.uuid4()
        self.store.put_quarantine(linked, b"synthetic linked data")
        self.store.put_quarantine(orphan, b"synthetic orphan data")
        report = audit_private_quarantine(
            root=self.root, referenced_keys={linked, missing})
        self.assertEqual(report.referenced, 1)
        self.assertEqual(report.orphans, (orphan.hex,))
        self.assertEqual(report.missing, (missing.hex,))
        self.assertFalse(report.deletion_authorized)
        self.assertTrue((self.root / orphan.hex).exists())

    def test_symlink_is_unsafe_never_followed(self):
        outside = Path(self.temp.name) / "outside"
        outside.write_bytes(b"synthetic")
        name = uuid.uuid4().hex
        (self.root / name).symlink_to(outside)
        report = audit_private_quarantine(root=self.root, referenced_keys=set())
        self.assertEqual(report.unsafe, (name,))
        self.assertTrue(outside.exists())

    def test_reject_broad_root_permissions_and_bad_references(self):
        os.chmod(self.root, 0o755)
        with self.assertRaises(PrivateStoreError):
            audit_private_quarantine(root=self.root, referenced_keys=set())
        os.chmod(self.root, 0o700)
        with self.assertRaises(PrivateStoreError):
            audit_private_quarantine(root=self.root, referenced_keys={"bad"})

    def test_unknown_file_does_not_delete_anything(self):
        marker = self.root / "README"
        marker.write_text("synthetic")
        report = audit_private_quarantine(root=self.root, referenced_keys=set())
        self.assertEqual(report.unsafe, ("README",))
        self.assertTrue(marker.exists())
