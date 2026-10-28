import hashlib
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .attachment_clamav_adapter import ScannerResult
from .attachment_private_store import PrivateQuarantineStore
from .attachment_scanner_worker import scan_and_attest_quarantine
from .attachment_scan_contract import verify_scan_verdict


class OfflineScannerWorkerTests(SimpleTestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name) / "objects"
        root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(root, Fernet.generate_key())
        content = b"%PDF-1.7\nstartxref\n1\n%%EOF"
        self.item = SimpleNamespace(
            state="quarantined", storage_key=uuid.uuid4(),
            display_name="fictional.pdf", content_type="application/pdf",
            byte_size=len(content), sha256=hashlib.sha256(content).hexdigest())
        self.store.put_quarantine(self.item.storage_key, content)
        self.key = b"synthetic-signing-key-which-is-32-bytes-plus"
        self.now = datetime(2026, 10, 28, 12, tzinfo=timezone.utc)

    def run_worker(self, verdict):
        return scan_and_attest_quarantine(
            store=self.store, attachment=self.item, socket_path="/tmp/test",
            engine="synthetic-scanner-v1", signing_key=self.key, now=self.now,
            scanner=lambda **kwargs: ScannerResult(verdict, "fictional"))

    def test_clean_is_attested_but_never_released(self):
        result = self.run_worker("clean")
        self.assertEqual(result.verdict, "attested")
        self.assertFalse(result.release_allowed)
        self.assertTrue(verify_scan_verdict(
            payload=result.attestation, signature=result.signature,
            verification_key=self.key, attachment=self.item, now=self.now))

    def test_unsafe_outcomes_never_signed(self):
        for verdict in ("infected", "error", "unknown"):
            with self.subTest(verdict=verdict):
                result = self.run_worker(verdict)
                self.assertEqual(result.verdict, "blocked")
                self.assertIsNone(result.signature)
                self.assertFalse(result.release_allowed)

    def test_modified_metadata_prevents_signing(self):
        self.item.sha256 = "0" * 64
        result = self.run_worker("clean")
        self.assertEqual(result.verdict, "blocked")
        self.assertIsNone(result.signature)

    def test_metadata_changed_during_scan_never_signed(self):
        def mutate(**kwargs):
            self.item.sha256 = "0" * 64
            return ScannerResult("clean", "fictional")
        result = scan_and_attest_quarantine(
            store=self.store, attachment=self.item, socket_path="/tmp/test",
            engine="synthetic-scanner-v1", signing_key=self.key, now=self.now,
            scanner=mutate)
        self.assertEqual(result.verdict, "blocked")
        self.assertIsNone(result.signature)

    def test_state_changed_during_scan_never_signed(self):
        def mutate(**kwargs):
            self.item.state = "clean"
            return ScannerResult("clean", "fictional")
        result = scan_and_attest_quarantine(
            store=self.store, attachment=self.item, socket_path="/tmp/test",
            engine="synthetic-scanner-v1", signing_key=self.key, now=self.now,
            scanner=mutate)
        self.assertEqual(result.verdict, "blocked")
        self.assertFalse(result.release_allowed)

    def test_untrusted_key_prevents_signing(self):
        self.key = b"short"
        result = self.run_worker("clean")
        self.assertEqual(result.verdict, "blocked")
