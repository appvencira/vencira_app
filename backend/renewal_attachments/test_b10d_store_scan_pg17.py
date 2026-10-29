import hashlib
import os
import tempfile
import uuid
from datetime import date
from pathlib import Path
from unittest.mock import Mock

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.test import (
    TransactionTestCase, override_settings,
)

from reminders.models import Workspace, Renewal
from reminders.attachment_private_store import (
    PrivateQuarantineStore,
)
from .models import (
    RenewalAttachment, AttachmentScanEvidence,
)
from .clamd_adapter import (
    MalwareDetected, MalwareScanUnavailable,
)
from .offline_store_scan_b10d import (
    scan_stored_quarantine_offline,
    ScanPipelineRejected,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B10DStoreScanTests(TransactionTestCase):
    def setUp(self):
        self.content = b"B10D TEST DOCUMENT ONLY"
        self.tmp = tempfile.TemporaryDirectory(
            prefix="b10d-synthetic-"
        )
        os.chmod(self.tmp.name, 0o700)

        self.root = Path(self.tmp.name)
        self.store = PrivateQuarantineStore(
            self.root, Fernet.generate_key()
        )

        ws = Workspace.objects.create(
            name="B10D test"
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B10D",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )

        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(self.content),
            sha256=hashlib.sha256(
                self.content
            ).hexdigest(),
            state=RenewalAttachment.State.QUARANTINED,
        )
        self.store.put_quarantine(
            self.item.storage_key, self.content
        )

    def tearDown(self):
        self.tmp.cleanup()

    def scan(self, scanner=None):
        return scan_stored_quarantine_offline(
            attachment_id=self.item.pk,
            store=self.store,
            verification_key=b"b10d-test-key-" + b"x" * 32,
            socket_path="/tmp/b10d-clamd-test.sock",
            scanner=scanner or Mock(return_value=None),
        )

    def test_clean_stays_quarantined(self):
        evidence = self.scan()
        self.assertEqual(
            evidence.payload["verdict"], "clean"
        )
        self.item.refresh_from_db()
        self.assertEqual(
            self.item.state, "quarantined"
        )
        self.assertEqual(
            AttachmentScanEvidence.objects.count(), 1
        )

    def test_infection_rejected(self):
        with self.assertRaises(MalwareDetected):
            self.scan(Mock(
                side_effect=MalwareDetected("EICAR TEST")
            ))
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_scanner_unavailable_rejected(self):
        with self.assertRaises(MalwareScanUnavailable):
            self.scan(Mock(
                side_effect=MalwareScanUnavailable("offline")
            ))
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_missing_ciphertext_rejected(self):
        (self.root / self.item.storage_key.hex).unlink()
        with self.assertRaises(ScanPipelineRejected):
            self.scan()
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_corrupted_ciphertext_rejected(self):
        (self.root / self.item.storage_key.hex).write_bytes(
            b"corrupted"
        )
        with self.assertRaises(ScanPipelineRejected):
            self.scan()

    def test_wrong_plaintext_digest_rejected(self):
        self.item.sha256 = "0" * 64
        self.item.save(update_fields=["sha256"])
        scanner = Mock(return_value=None)
        with self.assertRaises(ScanPipelineRejected):
            self.scan(scanner)
        scanner.assert_not_called()

    def test_rejected_document_not_scanned(self):
        self.item.state = RenewalAttachment.State.REJECTED
        self.item.save(update_fields=["state"])
        with self.assertRaises(ScanPipelineRejected):
            self.scan()

    def test_symlink_object_rejected(self):
        path = self.root / self.item.storage_key.hex
        path.unlink()
        path.symlink_to("/etc/hosts")
        with self.assertRaises(ScanPipelineRejected):
            self.scan()
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.scan()

    def test_duplicate_scan_denied(self):
        self.scan()
        with self.assertRaises(PermissionDenied):
            self.scan()

    def test_no_download_even_when_marked_clean(self):
        from reminders.attachment_gate import (
            may_download_attachment,
        )
        self.item.state = RenewalAttachment.State.CLEAN
        self.item.save(update_fields=["state"])
        self.assertFalse(
            may_download_attachment(
                attachment=self.item,
                membership=None,
            )
        )
