"""Synthetic offline intake authorization and encrypted storage tests."""
import tempfile
from datetime import date
from pathlib import Path

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.http import Http404
from django.test import TransactionTestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.models import Renewal, Workspace, WorkspaceMember
from django.contrib.auth import get_user_model
from .models import RenewalAttachment
from .offline_intake import stage_authorized_attachment


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class OfflineIntakeTests(TransactionTestCase):
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
        self.assertTrue(report.evidence_recorded)
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
        self.assertFalse(report.evidence_recorded)
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
        with self.assertRaises(PermissionDenied):
            persist_scan_evidence_offline(
                attachment_id=item.pk, payload=payload,
                signature=signature, verification_key=key)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_scan_evidence_cannot_be_recorded_in_production(self):
        from .offline_scan_evidence import persist_scan_evidence_offline
        item = self.intake()
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                persist_scan_evidence_offline(
                    attachment_id=item.pk, payload={},
                    signature="0" * 64, verification_key=b"e" * 32)

    def test_readiness_requires_signature_and_matching_encrypted_bytes(self):
        from reminders.attachment_scan_attestation import issue_scan_attestation
        from .offline_scan_evidence import persist_scan_evidence_offline
        from .offline_readiness import assess_attachment_readiness
        key = b"r" * 32
        item = self.intake()
        base = dict(member=self.member, attachment_id=item.pk,
                    store=self.store, verification_key=key)
        pending = assess_attachment_readiness(**base)
        self.assertFalse(pending.ready_for_security_review)
        payload, signature = issue_scan_attestation(
            attachment=item, verdict="clean", engine="synthetic-only",
            signing_key=key)
        persist_scan_evidence_offline(
            attachment_id=item.pk, payload=payload, signature=signature,
            verification_key=key)
        ready = assess_attachment_readiness(**base)
        self.assertTrue(ready.ready_for_security_review)
        self.assertFalse(ready.release_allowed)

    def test_readiness_denies_foreign_workspace(self):
        from .offline_readiness import assess_attachment_readiness
        item = self.intake()
        result = assess_attachment_readiness(
            member=self.foreign_member, attachment_id=item.pk,
            store=self.store, verification_key=b"r" * 32)
        self.assertFalse(result.metadata_authorized)
        self.assertFalse(result.ready_for_security_review)
        self.assertFalse(result.release_allowed)

    def test_readiness_denies_tampered_metadata_after_attestation(self):
        from reminders.attachment_scan_attestation import issue_scan_attestation
        from .offline_scan_evidence import persist_scan_evidence_offline
        from .offline_readiness import assess_attachment_readiness
        key = b"r" * 32
        item = self.intake()
        payload, signature = issue_scan_attestation(
            attachment=item, verdict="clean", engine="synthetic-only",
            signing_key=key)
        persist_scan_evidence_offline(
            attachment_id=item.pk, payload=payload, signature=signature,
            verification_key=key)
        RenewalAttachment.objects.filter(pk=item.pk).update(sha256="0" * 64)
        result = assess_attachment_readiness(
            member=self.member, attachment_id=item.pk,
            store=self.store, verification_key=key)
        self.assertFalse(result.signed_evidence_valid)
        self.assertFalse(result.ready_for_security_review)
        self.assertFalse(result.release_allowed)

    def test_readiness_denies_missing_encrypted_object(self):
        from reminders.attachment_scan_attestation import issue_scan_attestation
        from .offline_scan_evidence import persist_scan_evidence_offline
        from .offline_readiness import assess_attachment_readiness
        key = b"r" * 32
        item = self.intake()
        payload, signature = issue_scan_attestation(
            attachment=item, verdict="clean", engine="synthetic-only",
            signing_key=key)
        persist_scan_evidence_offline(
            attachment_id=item.pk, payload=payload, signature=signature,
            verification_key=key)
        self.store.discard_quarantine(item.storage_key)
        result = assess_attachment_readiness(
            member=self.member, attachment_id=item.pk,
            store=self.store, verification_key=key)
        self.assertTrue(result.signed_evidence_valid)
        self.assertFalse(result.encrypted_object_integrity)
        self.assertFalse(result.ready_for_security_review)
        self.assertFalse(result.release_allowed)

    def test_real_adapter_default_fails_closed_without_clamd_socket(self):
        from .offline_scan_flow import intake_scan_offline
        from .models import AttachmentScanEvidence
        result = intake_scan_offline(
            member=self.member, renewal_id=self.renewal.pk,
            store=self.store, filename="synthetic.jpg",
            content_type="image/jpeg",
            content=bytes.fromhex("ffd8ff00") + b"synthetic" + bytes.fromhex("ffd9"),
            unix_socket="/tmp/vencira-nonexistent-clamd-test.sock",
            engine="clamav-isolated-test", signing_key=b"s" * 32)
        self.assertEqual(result.verdict, "blocked")
        self.assertFalse(result.attested)
        self.assertFalse(result.evidence_recorded)
        self.assertFalse(result.release_allowed)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)
        self.assertEqual(RenewalAttachment.objects.get(
            pk=result.attachment_id).state, "quarantined")

    def test_scan_flow_rejects_db_metadata_changed_while_scanning(self):
        from reminders.attachment_clamav_adapter import ScannerResult
        from .offline_scan_flow import intake_scan_offline
        from .models import AttachmentScanEvidence

        def mutate_during_scan(*, payload, unix_socket):
            RenewalAttachment.objects.update(display_name="altered-after-staging.jpg")
            return ScannerResult("clean", "SYNTHETIC")

        outcome = intake_scan_offline(
            member=self.member, renewal_id=self.renewal.pk,
            store=self.store, filename="synthetic.jpg",
            content_type="image/jpeg",
            content=bytes.fromhex("ffd8ff00") + b"synthetic" + bytes.fromhex("ffd9"),
            unix_socket="/tmp/synthetic-test-only",
            engine="synthetic-scanner", signing_key=b"s" * 32,
            scanner=mutate_during_scan)
        self.assertEqual(outcome.verdict, "blocked")
        self.assertFalse(outcome.evidence_recorded)
        self.assertFalse(outcome.release_allowed)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)

    def test_owner_rejects_quarantine_and_discards_encrypted_bytes(self):
        from .offline_rejection import reject_attachment_offline
        item = self.intake()
        path = Path(self.temp.name) / item.storage_key.hex
        self.assertTrue(path.exists())
        result = reject_attachment_offline(
            member=self.member, attachment_id=item.pk, store=self.store)
        self.assertEqual(result.state, "rejected")
        self.assertTrue(result.private_object_discarded)
        self.assertFalse(result.release_allowed)
        self.assertFalse(path.exists())
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state, "rejected")
        with self.assertRaises(PermissionDenied):
            reject_attachment_offline(
                member=self.member, attachment_id=item.pk, store=self.store)

    def test_foreign_workspace_cannot_reject_or_discard(self):
        from .offline_rejection import reject_attachment_offline
        item = self.intake()
        path = Path(self.temp.name) / item.storage_key.hex
        with self.assertRaises(Http404):
            reject_attachment_offline(
                member=self.foreign_member, attachment_id=item.pk, store=self.store)
        self.assertTrue(path.exists())
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state, "quarantined")

    def test_rejection_storage_failure_retains_rejected_record(self):
        from unittest.mock import patch
        from reminders.attachment_private_store import PrivateStoreError
        from .offline_rejection import reject_attachment_offline
        item = self.intake()
        with patch.object(self.store, "discard_quarantine",
                          side_effect=PrivateStoreError("synthetic failure")):
            result = reject_attachment_offline(
                member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(result.needs_storage_reconciliation)
        self.assertFalse(result.private_object_discarded)
        self.assertFalse(result.release_allowed)
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state, "rejected")

    def test_rejected_cleanup_can_be_retried_without_reactivating_document(self):
        from unittest.mock import patch
        from reminders.attachment_private_store import PrivateStoreError
        from .offline_rejection import reject_attachment_offline
        from .offline_rejection_recovery import retry_rejected_discard_offline
        item = self.intake()
        path = Path(self.temp.name) / item.storage_key.hex
        with patch.object(self.store, "discard_quarantine",
                          side_effect=PrivateStoreError("temporary storage failure")):
            first = reject_attachment_offline(
                member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(first.needs_storage_reconciliation)
        self.assertTrue(path.exists())
        with self.assertRaises(Http404):
            retry_rejected_discard_offline(
                member=self.foreign_member, attachment_id=item.pk, store=self.store)
        recovered = retry_rejected_discard_offline(
            member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(recovered.private_object_discarded)
        self.assertFalse(recovered.release_allowed)
        self.assertFalse(path.exists())
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state, "rejected")

    def test_cleanup_cannot_run_inside_uncommitted_transaction(self):
        from django.db import transaction
        from .offline_rejection import reject_attachment_offline
        from .offline_rejection_recovery import retry_rejected_discard_offline
        item = self.intake()
        path = Path(self.temp.name) / item.storage_key.hex
        with transaction.atomic():
            with self.assertRaises(PermissionDenied):
                reject_attachment_offline(
                    member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(path.exists())
        self.assertEqual(RenewalAttachment.objects.get(pk=item.pk).state, "quarantined")
        reject_attachment_offline(
            member=self.member, attachment_id=item.pk, store=self.store)
        with transaction.atomic():
            with self.assertRaises(PermissionDenied):
                retry_rejected_discard_offline(
                    member=self.member, attachment_id=item.pk, store=self.store)

    def test_missing_object_after_rejection_completes_pending_job(self):
        from unittest.mock import patch
        from reminders.attachment_private_store import PrivateStoreError
        from .offline_rejection import reject_attachment_offline
        from .offline_rejection_recovery import retry_rejected_discard_offline
        from .models import AttachmentDiscardJob

        item = self.intake()
        with patch.object(self.store, "discard_quarantine",
                          side_effect=PrivateStoreError("synthetic failure")):
            reject_attachment_offline(
                member=self.member, attachment_id=item.pk, store=self.store)

        # Simula caída después del unlink y antes de confirmar el trabajo.
        self.store.discard_quarantine(item.storage_key)
        outcome = retry_rejected_discard_offline(
            member=self.member, attachment_id=item.pk, store=self.store)

        self.assertTrue(outcome.private_object_discarded)
        self.assertFalse(outcome.release_allowed)
        self.assertEqual(
            AttachmentDiscardJob.objects.get(attachment=item).status,
            "completed")
        self.assertEqual(
            RenewalAttachment.objects.get(pk=item.pk).state, "rejected")

    def test_discard_outbox_survives_storage_failure_and_records_retry(self):
        from unittest.mock import patch
        from reminders.attachment_private_store import PrivateStoreError
        from .offline_rejection import reject_attachment_offline
        from .offline_rejection_recovery import retry_rejected_discard_offline
        from .models import AttachmentDiscardJob
        item = self.intake()
        with patch.object(self.store, "discard_quarantine",
                          side_effect=PrivateStoreError("synthetic outage")):
            outcome = reject_attachment_offline(
                member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(outcome.needs_storage_reconciliation)
        job = AttachmentDiscardJob.objects.get(attachment_id=item.pk)
        self.assertEqual(job.status, "pending")
        self.assertEqual(job.attempts, 1)
        recovered = retry_rejected_discard_offline(
            member=self.member, attachment_id=item.pk, store=self.store)
        self.assertTrue(recovered.private_object_discarded)
        job.refresh_from_db()
        self.assertEqual(job.status, "completed")
        self.assertEqual(job.attempts, 2)
        self.assertIsNotNone(job.completed_at)
        self.assertFalse(recovered.release_allowed)
