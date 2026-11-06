import hashlib
from datetime import date
from unittest.mock import Mock

from django.core.exceptions import PermissionDenied
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from .models import RenewalAttachment, AttachmentScanEvidence
from .clamd_adapter import (
    MalwareDetected, MalwareScanUnavailable,
)
from .offline_scan_pipeline_b10 import (
    scan_quarantine_offline, ScanPipelineRejected,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B10BCPipelineTests(TransactionTestCase):

    def setUp(self):
        self.content = b"B10 SYNTHETIC DOCUMENT"
        self.key = b"k" * 32
        ws = Workspace.objects.create(
            name="B10BC Synthetic"
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B10BC",
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

    def run_pipeline(self, scanner=None, **overrides):
        data = {
            "attachment_id": self.item.pk,
            "content": self.content,
            "verification_key": self.key,
            "socket_path": "/tmp/b10bc-test-clamd.sock",
            "scanner": scanner or Mock(return_value=None),
        }
        data.update(overrides)
        return scan_quarantine_offline(**data)

    def test_clean_signed_but_quarantined(self):
        evidence = self.run_pipeline()
        self.assertEqual(
            evidence.payload["verdict"], "clean"
        )
        self.item.refresh_from_db()
        self.assertEqual(
            self.item.state,
            RenewalAttachment.State.QUARANTINED,
        )
        self.assertEqual(
            AttachmentScanEvidence.objects.count(), 1
        )

    def test_detected_threat_never_creates_evidence(self):
        scanner = Mock(
            side_effect=MalwareDetected("test detection")
        )
        with self.assertRaises(MalwareDetected):
            self.run_pipeline(scanner=scanner)
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_scanner_down_fails_closed(self):
        scanner = Mock(
            side_effect=MalwareScanUnavailable("offline")
        )
        with self.assertRaises(MalwareScanUnavailable):
            self.run_pipeline(scanner=scanner)
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_unexpected_scanner_error_fails_closed(self):
        scanner = Mock(side_effect=RuntimeError("failure"))
        with self.assertRaises(MalwareScanUnavailable):
            self.run_pipeline(scanner=scanner)
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_content_modified_never_scanned(self):
        scanner = Mock(return_value=None)
        with self.assertRaises(ScanPipelineRejected):
            self.run_pipeline(
                scanner=scanner,
                content=b"B10 SYNTHETIC DOCUMENX",
            )
        scanner.assert_not_called()

    def test_rejected_state_never_scanned(self):
        self.item.state = RenewalAttachment.State.REJECTED
        self.item.save(update_fields=["state"])
        scanner = Mock(return_value=None)
        with self.assertRaises(ScanPipelineRejected):
            self.run_pipeline(scanner=scanner)
        scanner.assert_not_called()

    def test_duplicate_scan_evidence_rejected(self):
        self.run_pipeline()
        with self.assertRaises(PermissionDenied):
            self.run_pipeline()
        self.assertEqual(
            AttachmentScanEvidence.objects.count(), 1
        )

    def test_production_disabled(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.run_pipeline()

    def test_metadata_modified_during_scan(self):
        def change_metadata(content, *, socket_path):
            RenewalAttachment.objects.filter(
                pk=self.item.pk
            ).update(display_name="modified.pdf")

        with self.assertRaises(PermissionDenied):
            self.run_pipeline(scanner=change_metadata)

        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_invalid_key_rejected(self):
        with self.assertRaises(ScanPipelineRejected):
            self.run_pipeline(verification_key=b"short")
