import tempfile
import uuid
from datetime import date
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import TestCase

from .attachment_orphan_snapshot import audit_quarantine_against_database
from .attachment_private_store import PrivateQuarantineStore
from .models import Renewal, RenewalAttachment, Workspace, WorkspaceMember


class AttachmentOrphanSnapshotTests(TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "store"
        self.root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(self.root, Fernet.generate_key())
        self.user = get_user_model().objects.create_user(username="orphan_audit_test")
        self.workspace = Workspace.objects.create(name="Fictional audit")
        WorkspaceMember.objects.create(
            workspace=self.workspace, user=self.user, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.user,
            customer_reference="FAKE-001", full_name="Fiction",
            expires_on=date(2027, 2, 3))

    def test_report_has_missing_and_orphan_but_no_mutation(self):
        linked = uuid.uuid4()
        missing = uuid.uuid4()
        orphan = uuid.uuid4()
        for key in (linked, orphan):
            self.store.put_quarantine(key, b"synthetic test only")
        for key in (linked, missing):
            RenewalAttachment.objects.create(
                renewal=self.renewal, display_name="test.pdf",
                content_type="application/pdf", byte_size=16,
                sha256="a" * 64, storage_key=key)
        report = audit_quarantine_against_database(root=self.root)
        self.assertEqual(report.metadata_count, 2)
        self.assertEqual(report.audit.orphans, (orphan.hex,))
        self.assertEqual(report.audit.missing, (missing.hex,))
        self.assertTrue(report.advisory_only)
        self.assertFalse(report.deletion_authorized)
        self.assertFalse(report.audit.deletion_authorized)
        self.assertTrue((self.root / orphan.hex).exists())
        self.assertEqual(RenewalAttachment.objects.count(), 2)

    def test_excessive_snapshot_aborts_before_filesystem_audit(self):
        RenewalAttachment.objects.create(renewal=self.renewal, display_name="test.pdf",
            content_type="application/pdf", byte_size=16, sha256="a" * 64)
        with patch("reminders.attachment_orphan_snapshot.MAX_AUDIT_OBJECTS", 0):
            with self.assertRaises(ValueError):
                audit_quarantine_against_database(root=self.root)
