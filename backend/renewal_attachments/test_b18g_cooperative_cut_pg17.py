"""B18G PG17-only synthetic orchestration checks."""
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from django.db import close_old_connections, connections, connection
from django.test import TransactionTestCase, override_settings
from .offline_cooperative_capture_b18g import (
    REQUIRED_WRITERS, SyntheticCaptureRejected, capture_cooperative_synthetic,
)
from .offline_write_barrier_b06b import advisory_barrier


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class B18GCooperativeCutTests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        self.key = "a" * 32
        self.obj = b"synthetic-encrypted"
        self.journal = json.dumps({
            "version": 1, "storage_key": self.key, "state": "pending",
        }).encode()
        self.db = {self.key: {
            "cipher_sha256": hashlib.sha256(self.obj).hexdigest(),
            "journal_sha256": hashlib.sha256(self.journal).hexdigest(),
        }}
        self.marker = {
            "epoch": 1, "snapshot": "b18g",
            "inventory_sha256": hashlib.sha256(json.dumps(
                self.db, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        }

    def run_capture(self, **kw):
        args = dict(
            registered_writers=REQUIRED_WRITERS, drained=True,
            sample_before=lambda: self.marker.copy(),
            sample_components=lambda: dict(
                db_records=self.db, encrypted_objects={self.key: self.obj},
                journals={self.key: self.journal}),
            sample_after=lambda: self.marker.copy(),
        )
        args.update(kw)
        return capture_cooperative_synthetic(**args)

    def test_complete_capture_is_never_release(self):
        self.assertEqual(self.run_capture(), {
            "verified": True, "objects": 1, "release_authorized": False,
        })

    def test_missing_registered_writer_rejected(self):
        with self.assertRaises(SyntheticCaptureRejected):
            self.run_capture(registered_writers=REQUIRED_WRITERS - {"offline_intake"})

    def test_extra_unreviewed_writer_rejected(self):
        with self.assertRaises(SyntheticCaptureRejected):
            self.run_capture(registered_writers=REQUIRED_WRITERS | {"future_writer"})

    def test_not_drained_rejected(self):
        with self.assertRaises(SyntheticCaptureRejected):
            self.run_capture(drained=False)

    def test_mid_capture_changed_epoch_rejected(self):
        with self.assertRaises(SyntheticCaptureRejected):
            self.run_capture(sample_after=lambda: {**self.marker, "epoch": 2})

    def test_cooperative_writer_waits_until_capture_exits(self):
        begun, completed = Event(), Event()

        def writer():
            close_old_connections()
            try:
                begun.set()
                with advisory_barrier(capture=False, timeout=10):
                    completed.set()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            def sample():
                future = pool.submit(writer)
                self.assertTrue(begun.wait(3))
                self.assertFalse(completed.wait(0.2))
                return dict(db_records=self.db,
                            encrypted_objects={self.key: self.obj},
                            journals={self.key: self.journal})
            result = self.run_capture(sample_components=sample)
            future.result(timeout=10)
        self.assertTrue(completed.is_set())
        self.assertFalse(result["release_authorized"])
