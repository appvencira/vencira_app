"""Adversarial regression: attestation and mutable DB state cannot release bytes."""
import hashlib
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

from django.test import SimpleTestCase

from .attachment_gate import may_download_attachment
from .attachment_scan_attestation import issue_scan_attestation
from .attachment_scan_contract import verify_scan_verdict


class ReleaseBoundaryTests(SimpleTestCase):
    def setUp(self):
        self.key = b"synthetic-only-independent-scanner-secret-2026"
        self.attachment = SimpleNamespace(
            storage_key=uuid.uuid4(),
            sha256=hashlib.sha256(b"fictional-data").hexdigest(),
            state="quarantined",
        )
        self.now = datetime(2026, 10, 28, 13, tzinfo=timezone.utc)

    def test_valid_clean_attestation_never_unlocks_download(self):
        body, signature = issue_scan_attestation(
            attachment=self.attachment, verdict="clean",
            engine="synthetic", signing_key=self.key, now=self.now)
        self.assertTrue(verify_scan_verdict(
            payload=body, signature=signature,
            verification_key=self.key, attachment=self.attachment,
            now=self.now))
        for membership in (None, object()):
            for state in ("quarantined", "clean", "rejected"):
                with self.subTest(state=state):
                    self.attachment.state = state
                    self.assertIs(
                        may_download_attachment(
                            attachment=self.attachment,
                            membership=membership), False)

    def test_replayed_attestation_cannot_authorize_different_object(self):
        body, signature = issue_scan_attestation(
            attachment=self.attachment, verdict="clean",
            engine="synthetic", signing_key=self.key, now=self.now)
        other = SimpleNamespace(
            storage_key=uuid.uuid4(), sha256=self.attachment.sha256,
            state="clean")
        self.assertFalse(verify_scan_verdict(
            payload=body, signature=signature,
            verification_key=self.key, attachment=other,
            now=self.now))
        self.assertFalse(may_download_attachment(
            attachment=other, membership=object()))
