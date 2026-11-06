import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from django.test import SimpleTestCase
from .offline_freeze_mb1 import SyntheticWriterGate, FreezeError, capture_synthetic_set


class MB1FreezeTests(SimpleTestCase):
    def setUp(self):
        self.gate = SyntheticWriterGate()
        self.key = "a" * 32
        self.obj = b"synthetic-cipher"
        self.journal = json.dumps({"version": 1, "storage_key": self.key,
                                   "state": "pending"}).encode()
        self.db = {self.key: {
            "cipher_sha256": hashlib.sha256(self.obj).hexdigest(),
            "journal_sha256": hashlib.sha256(self.journal).hexdigest()}}
        self.marker = {"epoch": 1, "snapshot": "mb1-freeze",
            "inventory_sha256": hashlib.sha256(json.dumps(
                self.db,sort_keys=True,separators=(",",":")).encode()).hexdigest()}

    def capture(self, **changes):
        args = dict(sample_before=lambda: self.marker.copy(),
                    sample_components=lambda: dict(
                        db_records=self.db,
                        encrypted_objects={self.key: self.obj},
                        journals={self.key: self.journal}),
                    sample_after=lambda: self.marker.copy())
        args.update(changes)
        return capture_synthetic_set(self.gate, **args)

    def test_integral_cut_synthetic(self):
        result = self.capture()
        self.assertTrue(result["verified"])
        self.assertFalse(result["release_authorized"])

    def test_new_writer_rejected_during_cut(self):
        def check():
            with self.assertRaisesRegex(FreezeError, "FREEZE_REJECTS_NEW_WRITER"):
                with self.gate.writer():
                    pass
            return dict(db_records=self.db, encrypted_objects={self.key:self.obj},
                        journals={self.key:self.journal})
        self.capture(sample_components=check)

    def test_active_writer_drained_before_capture(self):
        entered, release = Event(), Event()
        def writer():
            with self.gate.writer():
                entered.set()
                release.wait(5)
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(writer)
            self.assertTrue(entered.wait(2))
            with self.assertRaisesRegex(FreezeError, "ACTIVE_WRITERS_NOT_DRAINED"):
                with self.gate.freeze(timeout=0.05):
                    pass
            release.set()
            future.result(timeout=3)
        self.assertTrue(self.capture()["verified"])

    def test_capture_failure_releases_freeze(self):
        def failure():
            raise RuntimeError("SYNTHETIC_SNAPSHOT_INTERRUPTED")
        with self.assertRaisesRegex(RuntimeError, "SYNTHETIC_SNAPSHOT_INTERRUPTED"):
            self.capture(sample_components=failure)
        with self.gate.writer():
            pass

    def test_missing_component_rejected_and_unfrozen(self):
        with self.assertRaisesRegex(FreezeError, "MISSING_CAPTURE_COMPONENTS"):
            self.capture(sample_components=lambda: {})
        with self.gate.writer():
            pass

    def test_duplicate_capture_rejected(self):
        with self.gate.freeze():
            with self.assertRaisesRegex(FreezeError, "CAPTURE_ALREADY_ACTIVE"):
                with self.gate.freeze():
                    pass

    def test_changed_epoch_is_rejected(self):
        from .offline_capture_set_b18e import CaptureSetError
        with self.assertRaises(CaptureSetError):
            self.capture(sample_after=lambda: {**self.marker, "epoch":2})

    def test_invalid_timeout(self):
        with self.assertRaisesRegex(FreezeError, "INVALID_TIMEOUT"):
            with self.gate.freeze(timeout=0):
                pass
