"""Synthetic offline intake authorization and encrypted storage tests."""
import tempfile
from datetime import date
from pathlib import Path

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.http import Http404
from django.test import TestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.models import Renewal, Workspace, WorkspaceMember
from django.contrib.auth import get_user_model
from .models import RenewalAttachment
from .offline_intake import stage_authorized_attachment


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class OfflineIntakeTests(TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        root.chmod(0o700)
        self.store = PrivateQuarantineStore(root, Fernet.generate_key())
        user = get_user_model()
        self.owner = user.objects.create_user(username="test_intake_owner")
        self.foreign = user.objects.create_user(username="test_intake_foreign")
        self.ws = Workspace.objects.create(name="synthetic workspace")
        other = Workspace.objects.create(name="foreign workspace")
        self.member = WorkspaceMember.objects.create(
            workspace=self.ws, user=self.owner, role=WorkspaceMember.Role.OWNER)
        self.foreign_member = WorkspaceMember.objects.create(
            workspace=other, user=self.foreign, role=WorkspaceMember.Role.OWNER)
        self.renewal = Renewal.objects.create(
            workspace=self.ws, full_name="Synthetic",
            customer_reference="SYNTHETIC", expires_on=date(2027, 8, 1))

    def intake(self, member=None, **kwargs):
        return stage_authorized_attachment(
            member=member or self.member, renewal_id=self.renewal.pk,
            store=self.store, filename=kwargs.get("filename", "synthetic.pdf"),
            content_type="application/pdf",
            content=kwargs.get("content", b"%PDF-1.4\nsynthetic\n%%EOF"))

    def test_encrypted_quarantine_and_owned_metadata(self):
        item = self.intake()
        self.assertEqual(item.state, "quarantined")
        self.assertEqual(item.renewal_id, self.renewal.pk)
        self.assertEqual(item.uploaded_by_id, self.owner.pk)
        self.assertEqual(RenewalAttachment.objects.count(), 1)
        self.assertEqual(self.store.read_quarantine_for_scanner_only(
            item.storage_key), b"%PDF-1.4\nsynthetic\n%%EOF")
        self.assertNotIn(b"%PDF", (Path(self.temp.name) / item.storage_key.hex).read_bytes())

    def test_other_workspace_is_rejected_before_file_creation(self):
        with self.assertRaises(Http404):
            self.intake(member=self.foreign_member)
        self.assertFalse(list(Path(self.temp.name).iterdir()))
        self.assertEqual(RenewalAttachment.objects.count(), 0)

    def test_invalid_header_does_not_create_metadata_or_files(self):
        with self.assertRaises(ValueError):
            self.intake(content=b"not a PDF")
        self.assertEqual(RenewalAttachment.objects.count(), 0)
        self.assertFalse(list(Path(self.temp.name).iterdir()))

    def test_intake_cannot_run_outside_test_environment(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.intake()
        self.assertEqual(RenewalAttachment.objects.count(), 0)

    def test_scan_flow_attests_only_clean_synthetic_content(self):
        from reminders.attachment_clamav_adapter import ScannerResult
        from .offline_scan_flow import intake_scan_offline
        key = b"s" * 32
        payload = b"\xff\xd8\xff\x00synthetic\xff\xd9"
        def clean_scanner(*, payload, unix_socket):
            return ScannerResult("clean", "SYNTHETIC")
        report = intake_scan_offline(
            member=self.member, renewal_id=self.renewal.pk,
            store=self.store, filename="synthetic.jpg",
            content_type="image/jpeg", content=payload,
            unix_socket="/tmp/synthetic-test-only",
            engine="synthetic-scanner", signing_key=key,
            scanner=clean_scanner)
        self.assertEqual(report.verdict, "attested")
        self.assertTrue(report.attested)
        self.assertFalse(report.release_allowed)
        self.assertEqual(RenewalAttachment.objects.get(
            pk=report.attachment_id).state, "quarantined")

    def test_scan_flow_infected_remains_quarantined(self):
        from reminders.attachment_clamav_adapter import ScannerResult
        from .offline_scan_flow import intake_scan_offline
        def infected(*, payload, unix_socket):
            return ScannerResult("infected", "SYNTHETIC")
        report = intake_scan_offline(
            member=self.member, renewal_id=self.renewal.pk,
            store=self.store, filename="synthetic.jpg",
            content_type="image/jpeg",
            content=b"\xff\xd8\xff\x00synthetic\xff\xd9",
            unix_socket="/tmp/synthetic-test-only",
            engine="synthetic-scanner", signing_key=b"s" * 32,
            scanner=infected)
        self.assertFalse(report.attested)
        self.assertFalse(report.release_allowed)
        self.assertEqual(RenewalAttachment.objects.get(
            pk=report.attachment_id).state, "quarantined")

    def test_scanner_error_and_exception_never_release_bytes(self):
        from reminders.attachment_clamav_adapter import ScannerResult
        from .offline_scan_flow import intake_scan_offline

        def failed_scanner(*, payload, unix_socket):
            return ScannerResult("error", "SCANNER_UNAVAILABLE")

        def broken_scanner(*, payload, unix_socket):
            raise ConnectionError("synthetic scanner disconnected")

        for scanner in (failed_scanner, broken_scanner):
            outcome = intake_scan_offline(
                member=self.member, renewal_id=self.renewal.pk,
                store=self.store, filename="synthetic.jpg",
                content_type="image/jpeg",
                content=b"\xff\xd8\xff\x00synthetic\xff\xd9",
                unix_socket="/tmp/synthetic-test-only",
                engine="synthetic-scanner", signing_key=b"s" * 32,
                scanner=scanner)
            self.assertEqual(outcome.verdict, "blocked")
            self.assertFalse(outcome.attested)
            self.assertFalse(outcome.release_allowed)
            self.assertEqual(RenewalAttachment.objects.get(
                pk=outcome.attachment_id).state, "quarantined")

    def test_signed_scan_evidence_is_persisted_without_release(self):
        from reminders.attachment_scan_attestation import issue_scan_attestation
        from .offline_scan_evidence import persist_scan_evidence_offline
        from .models import AttachmentScanEvidence
        key = b"e" * 32
        item = self.intake()
        payload, signature = issue_scan_attestation(
            attachment=item, verdict="clean",
            engine="synthetic-scanner", signing_key=key)
        evidence = persist_scan_evidence_offline(
            attachment_id=item.pk, payload=payload,
            signature=signature, verification_key=key)
        self.assertEqual(evidence.attachment_id, item.pk)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state,
                         "quarantined")
        with self.assertRaises(PermissionDenied):
            persist_scan_evidence_offline(
                attachment_id=item.pk, payload=payload,
                signature="0" * 64, verification_key=key)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_scan_evidence_cannot_be_recorded_in_production(self):
        from .offline_scan_evidence import persist_scan_evidence_offline
        item = self.intake()
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                persist_scan_evidence_offline(
                    attachment_id=item.pk, payload={},
                    signature="0" * 64, verification_key=b"e" * 32)
