"""D11 integration tests: encrypted synthetic PDF, journal, metadata and evidence."""
import hashlib
import hmac
import tempfile
from datetime import date
from pathlib import Path

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.test import TestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.models import Renewal, Workspace, WorkspaceMember
from .offline_intake import stage_authorized_attachment
from .offline_intake_journal import IntakeJournal
from .offline_preflight_d11 import inspect_attachment_preflight_offline

PDF = b"%PDF-1.4\nD11 synthetic only\n%%EOF"


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class D11OfflinePreflightTests(TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        private, records = root / "private", root / "journal"
        private.mkdir(mode=0o700)
        records.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(private, Fernet.generate_key())
        self.journal = IntakeJournal(records)
        user = get_user_model().objects.create_user(username="d11_preflight_user")
        ws = Workspace.objects.create(name="D11 synthetic")
        member = WorkspaceMember.objects.create(
            workspace=ws, user=user, role=WorkspaceMember.Role.OWNER
        )
        renewal = Renewal.objects.create(
            workspace=ws, full_name="Synthetic",
            customer_reference="D11-SYNTHETIC", expires_on=date(2027, 12, 1)
        )
        self.item = stage_authorized_attachment(
            member=member, renewal_id=renewal.pk, store=self.store,
            journal=self.journal, filename="synthetic.pdf",
            content_type="application/pdf", content=PDF,
        )
        self.secret = b"synthetic-key-material-" + b"k" * 32
        self.evidence = {
            "sha256": hashlib.sha256(PDF).hexdigest(),
            "verdict": "clean", "engine": "synthetic", "version": "v1",
        }

    def check(self, **overrides):
        evidence = overrides.pop("evidence", self.evidence)
        payload = "|".join(
            (evidence["sha256"], evidence["verdict"], evidence["engine"], evidence["version"])
        ).encode()
        signature = hmac.new(self.secret, payload, hashlib.sha256).hexdigest()
        params = dict(
            attachment=self.item, journal=self.journal, store=self.store,
            evidence=evidence, signature=signature, secret=self.secret,
        )
        params.update(overrides)
        return inspect_attachment_preflight_offline(**params)

    def test_clean_signed_evidence_still_never_releases(self):
        result = self.check()
        self.assertTrue(result["object_verified"])
        self.assertTrue(result["scanner_evidence_verified"])
        self.assertFalse(result["release_authorized"])
        self.assertFalse(result["download_allowed"])

    def test_tampered_signature_denied(self):
        result = self.check(signature="0" * 64)
        self.assertFalse(result["scanner_evidence_verified"])
        self.assertFalse(result["release_authorized"])

    def test_digest_mismatch_denied(self):
        self.item.sha256 = "0" * 64
        result = self.check()
        self.assertFalse(result["metadata_consistent"])
        self.assertFalse(result["release_authorized"])

    def test_rejected_verdict_denied(self):
        infected = dict(self.evidence, verdict="infected")
        result = self.check(evidence=infected)
        self.assertFalse(result["scanner_evidence_verified"])
        self.assertFalse(result["download_allowed"])

    def test_non_test_environment_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.check()
