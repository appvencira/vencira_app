import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from django.test import SimpleTestCase
from .attachment_scan_attestation import issue_scan_attestation
from .attachment_scan_contract import verify_scan_verdict


class AttachmentAttestationTests(SimpleTestCase):
    def setUp(self):
        self.key = b"scanner-signing-key-synthetic-32-bytes-2026"
        self.item = SimpleNamespace(
            storage_key=uuid.uuid4(),
            sha256=hashlib.sha256(b"synthetic").hexdigest(),
            state="quarantined",
        )
        self.now = datetime(2026, 10, 28, 10, tzinfo=timezone.utc)

    def test_clean_signature_roundtrip_only_for_same_object(self):
        body, signature = issue_scan_attestation(
            attachment=self.item, verdict="clean",
            engine="synthetic-scan-1", signing_key=self.key, now=self.now,
        )
        self.assertTrue(verify_scan_verdict(
            payload=body, signature=signature, verification_key=self.key,
            attachment=self.item, now=self.now,
        ))
        self.item.sha256 = hashlib.sha256(b"different").hexdigest()
        self.assertFalse(verify_scan_verdict(
            payload=body, signature=signature, verification_key=self.key,
            attachment=self.item, now=self.now,
        ))

    def test_infected_never_means_releasable(self):
        body, signature = issue_scan_attestation(
            attachment=self.item, verdict="infected",
            engine="synthetic", signing_key=self.key, now=self.now,
        )
        self.assertFalse(verify_scan_verdict(
            payload=body, signature=signature, verification_key=self.key,
            attachment=self.item, now=self.now,
        ))

    def test_stale_scan_rejected(self):
        body, signature = issue_scan_attestation(
            attachment=self.item, verdict="clean",
            engine="synthetic", signing_key=self.key,
            now=self.now - timedelta(hours=2),
        )
        self.assertFalse(verify_scan_verdict(
            payload=body, signature=signature, verification_key=self.key,
            attachment=self.item, now=self.now,
        ))

    def test_only_quarantine_may_be_attested(self):
        self.item.state = "clean"
        with self.assertRaises(ValueError):
            issue_scan_attestation(
                attachment=self.item, verdict="clean",
                engine="synthetic", signing_key=self.key, now=self.now,
            )
