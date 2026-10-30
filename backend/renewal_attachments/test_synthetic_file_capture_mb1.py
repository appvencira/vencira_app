import hashlib
import json
import os
import tempfile
from pathlib import Path
from django.test import SimpleTestCase
from .offline_multiprocess_fence_mb1 import IsolatedProcessFence
from .offline_synthetic_file_capture_mb1 import (
    capture_synthetic_files, SyntheticFileCaptureError,
)
from .offline_capture_set_b18e import CaptureSetError


class MB1PhysicalFixtureCaptureTests(SimpleTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        os.chmod(self.root, 0o700)
        for name in ("objects", "journal"):
            (self.root / name).mkdir(mode=0o700)
        self.key = "a" * 32
        self.obj = b"synthetic-ciphertext"
        self.journal = json.dumps({"version":1, "storage_key":self.key,
                                   "state":"pending"}).encode()
        records = {self.key: {
            "cipher_sha256":hashlib.sha256(self.obj).hexdigest(),
            "journal_sha256":hashlib.sha256(self.journal).hexdigest()}}
        (self.root / "db_inventory.json").write_text(json.dumps(records))
        (self.root / "objects" / self.key).write_bytes(self.obj)
        (self.root / "journal" / (self.key+".json")).write_bytes(self.journal)
        self.fence = IsolatedProcessFence(self.root / "fence.lock")

    def run_capture(self):
        return capture_synthetic_files(
            fence=self.fence, root=self.root, snapshot="mb1-physical",
            epoch=1)

    def test_consistent_three_component_fixture(self):
        result = self.run_capture()
        self.assertTrue(result["verified"])
        self.assertFalse(result["release_authorized"])

    def test_corrupt_object_rejected(self):
        (self.root / "objects" / self.key).write_bytes(b"tamper")
        with self.assertRaises(CaptureSetError):
            self.run_capture()

    def test_missing_journal_rejected(self):
        (self.root / "journal" / (self.key+".json")).unlink()
        with self.assertRaises(SyntheticFileCaptureError):
            self.run_capture()

    def test_missing_inventory_rejected(self):
        (self.root / "db_inventory.json").unlink()
        with self.assertRaises(SyntheticFileCaptureError):
            self.run_capture()

    def test_invalid_root_permissions_rejected(self):
        os.chmod(self.root, 0o755)
        with self.assertRaises(SyntheticFileCaptureError):
            self.run_capture()

    def test_noncooperative_write_is_not_prevented(self):
        # Explicit negative proof: a process that doesn't take the lock can
        # tamper even while capture holds it. Thus no production guarantee.
        with self.fence.capture():
            (self.root / "objects" / self.key).write_bytes(b"tamper")
        with self.assertRaises(CaptureSetError):
            self.run_capture()
