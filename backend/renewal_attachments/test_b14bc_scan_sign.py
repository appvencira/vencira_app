import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)
from django.test import SimpleTestCase, override_settings

from reminders.attachment_clamav_adapter import ScannerResult
from .offline_ed25519_b13b import public_key_bytes
from .offline_key_registry_b13d import TrustedPublicKey
from .offline_keyed_v3_b13e import verify_keyed_verdict
from b14_isolation_rehearsal.scan_sign_contract import (
    scan_and_sign_v3,
)


class SyntheticStore:
    def __init__(self, data):
        self.data = data

    def read_quarantine_for_scanner_only(self, key):
        return self.data


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B14ScanSignTests(SimpleTestCase):

    def setUp(self):
        self.content = b"%PDF-1.7\nstartxref\n1\n%%EOF"
        self.store = SyntheticStore(self.content)
        self.item = SimpleNamespace(
            storage_key=uuid.uuid4(),
            sha256=hashlib.sha256(self.content).hexdigest(),
            byte_size=len(self.content),
            state="quarantined",
            display_name="synthetic.pdf",
            content_type="application/pdf",
        )
        self.private = Ed25519PrivateKey.generate()
        self.now = datetime.now(timezone.utc)

    def run_scan(self, verdict="clean", scanner=None, **changes):
        if scanner is None:
            scanner = lambda **kwargs: ScannerResult(
                verdict, "synthetic"
            )
        args = dict(
            store=self.store,
            attachment=self.item,
            socket_path="/tmp/synthetic-clamd.sock",
            private_key=self.private,
            key_id="b14-synthetic",
            engine="synthetic-b14",
            scanner=scanner,
            now=self.now,
        )
        args.update(changes)
        return scan_and_sign_v3(**args)

    def test_clean_creates_verified_v3_without_release(self):
        outcome = self.run_scan()
        self.assertEqual(outcome.verdict, "attested")
        self.assertFalse(outcome.release_allowed)
        self.assertEqual(outcome.payload["key_id"], "b14-synthetic")
        self.assertEqual(len(outcome.signature), 128)

        public = public_key_bytes(self.private)
        registry = {
            "b14-synthetic": TrustedPublicKey(
                "b14-synthetic",
                public,
                self.now - timedelta(minutes=2),
                self.now + timedelta(minutes=2),
            )
        }
        self.assertTrue(verify_keyed_verdict(
            payload=outcome.payload,
            signature=outcome.signature,
            registry=registry,
            attachment=self.item,
            now=self.now,
        ))

    def test_infected_blocked(self):
        result = self.run_scan("infected")
        self.assertEqual(result.verdict, "blocked")
        self.assertIsNone(result.signature)

    def test_scanner_error_blocked(self):
        result = self.run_scan("error")
        self.assertEqual(result.verdict, "blocked")

    def test_metadata_mutation_blocked(self):
        def scanner(**kwargs):
            self.item.display_name = "changed.pdf"
            return ScannerResult("clean", "synthetic")

        result = self.run_scan(scanner=scanner)
        self.assertEqual(result.verdict, "blocked")

    def test_sha256_mismatch_blocked(self):
        self.item.sha256 = "0" * 64
        self.assertEqual(self.run_scan().verdict, "blocked")

    def test_size_mismatch_blocked(self):
        self.item.byte_size += 1
        self.assertEqual(self.run_scan().verdict, "blocked")

    def test_non_quarantine_blocked(self):
        self.item.state = "clean"
        self.assertEqual(self.run_scan().verdict, "blocked")

    def test_unavailable_scanner_blocked(self):
        def scanner(**kwargs):
            raise OSError("Unavailable")
        self.assertEqual(
            self.run_scan(scanner=scanner).verdict,
            "blocked",
        )

    def test_wrong_signing_key_blocked(self):
        result = self.run_scan(private_key=b"not-a-key")
        self.assertEqual(result.verdict, "blocked")

    def test_production_blocked(self):
        with override_settings(VENCIRA_ENV="production"):
            result = self.run_scan()
        self.assertEqual(result.verdict, "blocked")

    def test_missing_trust_flag_blocked(self):
        with override_settings(
            VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=False
        ):
            result = self.run_scan()
        self.assertEqual(result.verdict, "blocked")
