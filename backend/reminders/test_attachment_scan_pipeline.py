"""Synthetic integration of encrypted store and scanner adapter contract."""
import hashlib
import tempfile
import uuid
from pathlib import Path
from types import SimpleNamespace
from cryptography.fernet import Fernet
from django.test import SimpleTestCase
from .attachment_private_store import PrivateQuarantineStore
from .attachment_scan_pipeline import scan_encrypted_quarantine
from .attachment_clamav_adapter import ScannerResult


class QuarantinePipelineTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name) / "objects"
        root.mkdir(mode=0o700)
        self.store = PrivateQuarantineStore(root, Fernet.generate_key())
        self.payload = b"%PDF-1.7\nstartxref\n1\n%%EOF"
        self.item = SimpleNamespace(
            storage_key=uuid.uuid4(), state="quarantined", display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=len(self.payload),
            sha256=hashlib.sha256(self.payload).hexdigest(),
        )
        self.store.put_quarantine(self.item.storage_key, self.payload)

    def scan(self, verdict="clean"):
        def stub(*, payload, unix_socket):
            self.assertEqual(payload, self.payload)
            self.assertEqual(unix_socket, "/tmp/synthetic-scanner.sock")
            return ScannerResult(verdict, "synthetic")
        return scan_encrypted_quarantine(
            store=self.store, attachment=self.item,
            socket_path="/tmp/synthetic-scanner.sock", scanner=stub,
        )

    def test_clean_stays_quarantined(self):
        result = self.scan()
        self.assertEqual(result.verdict, "clean")
        self.assertFalse(result.release_allowed)

    def test_infected_and_error_always_block_release(self):
        for verdict in ("infected", "error"):
            with self.subTest(verdict=verdict):
                result = self.scan(verdict)
                self.assertEqual(result.verdict, verdict)
                self.assertFalse(result.release_allowed)

    def test_digest_mismatch_blocks_before_scanner(self):
        self.item.sha256 = "0" * 64
        result = scan_encrypted_quarantine(
            store=self.store, attachment=self.item, socket_path="/tmp/demo",
            scanner=lambda **kwargs: self.fail("scanner must not execute"))
        self.assertEqual(result.reason, "SHA256_MISMATCH")
        self.assertFalse(result.release_allowed)

    def test_wrong_size_and_missing_object_block(self):
        self.item.byte_size += 1
        result = self.scan_encrypted_without_scanner()
        self.assertEqual(result.reason, "SIZE_MISMATCH")
        self.item.byte_size -= 1
        self.item.storage_key = uuid.uuid4()
        result = self.scan_encrypted_without_scanner()
        self.assertEqual(result.verdict, "error")

    def scan_encrypted_without_scanner(self):
        return scan_encrypted_quarantine(
            store=self.store, attachment=self.item, socket_path="/tmp/demo",
            scanner=lambda **kwargs: self.fail("scanner must not execute"))
