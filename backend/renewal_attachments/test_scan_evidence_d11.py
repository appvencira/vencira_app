"""D11: tests de evidencia auténtica sintética; no integra antivirus real."""
import hashlib
import hmac

from django.core.exceptions import PermissionDenied
from django.test import SimpleTestCase, override_settings
from .offline_scan_evidence_d11 import verify_scan_evidence_offline


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class EvidenceD11Tests(SimpleTestCase):
    def setUp(self):
        self.content = b"SYNTHETIC_D11_ONLY"
        self.digest = hashlib.sha256(self.content).hexdigest()
        self.secret = b"k" * 32
        self.evidence = dict(
            sha256=self.digest, verdict="clean", engine="mock-engine", version="synthetic-v1"
        )
        self.signature = self.sign(self.evidence)

    def sign(self, evidence):
        payload = "|".join(
            (evidence["sha256"], evidence["verdict"], evidence["engine"], evidence["version"])
        ).encode()
        return hmac.new(self.secret, payload, hashlib.sha256).hexdigest()

    def check(self, **overrides):
        values = dict(
            content=self.content, expected_digest=self.digest,
            evidence=self.evidence, signature=self.signature, secret=self.secret
        )
        values.update(overrides)
        return verify_scan_evidence_offline(**values)

    def test_authentic_evidence(self):
        self.assertTrue(self.check())

    def test_unsigned_forgery_denied(self):
        self.assertFalse(self.check(signature="0" * 64))

    def test_mutated_bytes_denied(self):
        self.assertFalse(self.check(content=b"MODIFIED"))

    def test_replaced_digest_denied(self):
        self.assertFalse(self.check(expected_digest="0" * 64))

    def test_rejected_verdict_denied(self):
        bad = dict(self.evidence, verdict="infected")
        self.assertFalse(self.check(evidence=bad, signature=self.sign(bad)))

    def test_extra_field_denied(self):
        with self.assertRaises(PermissionDenied):
            self.check(evidence=dict(self.evidence, download=True))

    def test_short_signing_key_denied(self):
        with self.assertRaises(PermissionDenied):
            self.check(secret=b"short")

    def test_outside_rehearsal_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.check()
