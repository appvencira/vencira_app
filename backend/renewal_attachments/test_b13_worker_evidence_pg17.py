import hashlib
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

from cryptography.fernet import Fernet
from django.core.exceptions import PermissionDenied
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.attachment_clamav_adapter import ScannerResult
from reminders.attachment_scanner_worker import (
    WorkerOutcome, scan_and_attest_quarantine,
)
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_worker_evidence_b13 import (
    accept_worker_evidence_offline,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B13WorkerEvidencePG17Tests(TransactionTestCase):

    def setUp(self):
        self.content = b"%PDF-1.7\nstartxref\n1\n%%EOF"
        self.key = b"b13-synthetic-signing-key-1234567890"
        self.now = datetime.now(timezone.utc)

        self.temp = tempfile.TemporaryDirectory(
            prefix="b13-synthetic-"
        )
        self.addCleanup(self.temp.cleanup)

        import os
        os.chmod(self.temp.name, 0o700)

        self.store = PrivateQuarantineStore(
            Path(self.temp.name),
            Fernet.generate_key(),
        )

        ws = Workspace.objects.create(name="B13 synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B13",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(self.content),
            sha256=hashlib.sha256(self.content).hexdigest(),
            state=RenewalAttachment.State.QUARANTINED,
        )

        self.store.put_quarantine(
            self.item.storage_key, self.content
        )

    def fingerprint(self):
        fields = (
            "storage_key", "sha256", "byte_size",
            "state", "display_name", "content_type",
        )
        return tuple(getattr(self.item, f) for f in fields)

    def outcome(self, verdict="clean"):
        # Objeto que representa los metadatos leídos por
        # un trabajador independiente.
        attachment = SimpleNamespace(
            storage_key=self.item.storage_key,
            sha256=self.item.sha256,
            byte_size=self.item.byte_size,
            state=self.item.state,
            display_name=self.item.display_name,
            content_type=self.item.content_type,
        )

        return scan_and_attest_quarantine(
            store=self.store,
            attachment=attachment,
            socket_path="/tmp/b13-synthetic-clamd.sock",
            engine="b13-synthetic-engine",
            signing_key=self.key,
            scanner=lambda **kwargs:
                ScannerResult(verdict, "synthetic"),
            now=self.now,
        )

    def accept(self, outcome, **overrides):
        args = {
            "attachment_id": self.item.pk,
            "outcome": outcome,
            "verification_key": self.key,
            "expected_fingerprint": self.fingerprint(),
            "now": self.now,
        }
        args.update(overrides)
        return accept_worker_evidence_offline(**args)

    def test_clean_attested_and_quarantined(self):
        result = self.accept(self.outcome())
        self.assertEqual(
            result.payload["verdict"], "clean"
        )
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertEqual(
            AttachmentScanEvidence.objects.count(), 1
        )

    def test_infection_not_accepted(self):
        with self.assertRaises(PermissionDenied):
            self.accept(self.outcome("infected"))
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_scanner_error_not_accepted(self):
        with self.assertRaises(PermissionDenied):
            self.accept(self.outcome("error"))
        self.assertFalse(
            AttachmentScanEvidence.objects.exists()
        )

    def test_forged_signature_rejected(self):
        clean = self.outcome()
        forged = WorkerOutcome(
            verdict="attested",
            attestation=clean.attestation,
            signature="0" * 64,
        )
        with self.assertRaises(PermissionDenied):
            self.accept(forged)

    def test_wrong_verification_key_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.accept(
                self.outcome(),
                verification_key=b"x" * 32,
            )

    def test_metadata_changed_after_scan_rejected(self):
        clean = self.outcome()
        original = self.fingerprint()
        self.item.display_name = "changed.pdf"
        self.item.save(update_fields=["display_name"])
        with self.assertRaises(PermissionDenied):
            self.accept(
                clean, expected_fingerprint=original
            )

    def test_duplicate_attestation_rejected(self):
        clean = self.outcome()
        self.accept(clean)
        with self.assertRaises(PermissionDenied):
            self.accept(clean)

    def test_release_flag_is_rejected(self):
        clean = self.outcome()
        forged = WorkerOutcome(
            verdict="attested",
            attestation=clean.attestation,
            signature=clean.signature,
            release_allowed=True,
        )
        with self.assertRaises(PermissionDenied):
            self.accept(forged)

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.accept(self.outcome())

    def test_no_http_download_permission(self):
        from reminders.attachment_gate import (
            may_download_attachment,
        )
        self.accept(self.outcome())
        self.assertFalse(
            may_download_attachment(
                attachment=self.item,
                membership=None,
            )
        )
