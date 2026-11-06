"""Synthetic package + external-head binding tests, no Docker or real data."""
import hashlib
import hmac
import json
import os
from pathlib import Path
import tempfile
import unittest

from renewal_attachments.offline_antirollback_head_mb1 import AntiRollbackError
from renewal_attachments.offline_antirollback_package_mb1 import (
    issue_package_receipt, verify_package_antirollback,
)


class MB1PhysicalPackageAntiRollbackTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.manifest_key = b"synthetic-manifest-authentication-key-0001"
        self.receipt_key = b"synthetic-independent-receipt-key-0002"
        old_env = {key: os.environ.get(key) for key in (
            "VENCIRA_ENV", "MB1_DISPOSABLE_ONLY"
        )}
        self.addCleanup(lambda: [
            os.environ.pop(k, None) if v is None else os.environ.__setitem__(k, v)
            for k, v in old_env.items()
        ])
        os.environ["VENCIRA_ENV"] = "test"
        os.environ["MB1_DISPOSABLE_ONLY"] = "1"
        self.old = self.fixture("old", "mb1-first", b"synthetic-encrypted-capture-one")
        self.new = self.fixture("new", "mb1-second", b"synthetic-encrypted-capture-two")
        self.head1 = self.issue(self.old)
        self.head2 = self.issue(self.new, self.head1)

    def fixture(self, name, snap, envelope):
        directory = Path(self.temp.name) / name
        directory.mkdir(mode=0o700)
        manifest = {
            "snapshot": snap,
            "envelope_sha256": hashlib.sha256(envelope).hexdigest(),
            "database_sha256": "a" * 64,
            "object_sha256": "b" * 64,
            "journal_sha256": "c" * 64,
            "item": "a" * 32,
            "key_id": "synthetic-only",
        }
        encoded = json.dumps(
            manifest, separators=(",", ":"), sort_keys=True
        ).encode()
        mac = hmac.new(
            self.manifest_key, encoded, hashlib.sha256
        ).hexdigest().encode()
        for filename, data in (
            ("capture.enc", envelope),
            ("manifest.json", encoded),
            ("manifest.mac", mac),
        ):
            target = directory / filename
            target.write_bytes(data)
            target.chmod(0o600)
        return directory

    def issue(self, root, head=None):
        return issue_package_receipt(
            root, manifest_key=self.manifest_key,
            receipt_key=self.receipt_key, trusted_previous_head=head,
        )

    def restore(self, root, receipt, head):
        return verify_package_antirollback(
            root, manifest_key=self.manifest_key,
            receipt_key=self.receipt_key, candidate_receipt=receipt,
            trusted_external_head=head,
        )

    def test_latest_attested_three_file_package_accepted_for_synthetic_restore(self):
        result = self.restore(self.new, self.head2, self.head2)
        self.assertTrue(result["verified"])
        self.assertEqual(result["sequence"], 2)
        self.assertFalse(result["release_authorized"])

    def test_older_valid_package_and_receipt_rejected_by_external_head(self):
        with self.assertRaisesRegex(AntiRollbackError, "STALE_OR_UNTRUSTED_SNAPSHOT"):
            self.restore(self.old, self.head1, self.head2)

    def test_modified_encrypted_capture_rejected(self):
        (self.new / "capture.enc").write_bytes(b"tampered")
        with self.assertRaisesRegex(AntiRollbackError, "ENVELOPE_MANIFEST_MISMATCH"):
            self.restore(self.new, self.head2, self.head2)

    def test_modified_manifest_rejected(self):
        (self.new / "manifest.json").write_bytes(b'{"snapshot":"mb1-third"}')
        with self.assertRaisesRegex(AntiRollbackError, "MANIFEST_AUTHENTICATION_FAILED"):
            self.restore(self.new, self.head2, self.head2)

    def test_modified_mac_rejected(self):
        (self.new / "manifest.mac").write_bytes(b"0" * 64)
        with self.assertRaisesRegex(AntiRollbackError, "MANIFEST_AUTHENTICATION_FAILED"):
            self.restore(self.new, self.head2, self.head2)

    def test_missing_receipt_or_external_head_rejected(self):
        with self.assertRaises(AntiRollbackError):
            self.restore(self.new, self.head2, None)
        with self.assertRaises(AntiRollbackError):
            self.restore(self.new, None, self.head2)

    def test_wrong_manifest_key_rejected(self):
        with self.assertRaisesRegex(AntiRollbackError, "MANIFEST_AUTHENTICATION_FAILED"):
            verify_package_antirollback(
                self.new, manifest_key=b"wrong-manifest-key" * 3,
                receipt_key=self.receipt_key,
                candidate_receipt=self.head2, trusted_external_head=self.head2,
            )

    def test_wrong_receipt_key_rejected(self):
        with self.assertRaises(AntiRollbackError):
            verify_package_antirollback(
                self.new, manifest_key=self.manifest_key,
                receipt_key=b"wrong-receipt-key" * 3,
                candidate_receipt=self.head2, trusted_external_head=self.head2,
            )

    def test_one_missing_physical_file_rejected(self):
        (self.new / "manifest.mac").unlink()
        with self.assertRaisesRegex(AntiRollbackError, "UNREADABLE_PACKAGE_FILE"):
            self.restore(self.new, self.head2, self.head2)

    def test_insecure_package_file_mode_rejected(self):
        (self.new / "capture.enc").chmod(0o644)
        with self.assertRaisesRegex(AntiRollbackError, "UNSAFE_PACKAGE_FILE"):
            self.restore(self.new, self.head2, self.head2)

    def test_symlink_is_rejected(self):
        (self.new / "capture.enc").unlink()
        (self.new / "capture.enc").symlink_to(self.old / "capture.enc")
        with self.assertRaises(AntiRollbackError):
            self.restore(self.new, self.head2, self.head2)

    def test_test_only_gate_rejects_other_environments(self):
        os.environ["VENCIRA_ENV"] = "production"
        with self.assertRaisesRegex(AntiRollbackError, "SYNTHETIC_ONLY"):
            self.restore(self.new, self.head2, self.head2)


if __name__ == "__main__":
    unittest.main()
