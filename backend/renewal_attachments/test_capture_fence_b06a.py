import hashlib
import json
import uuid

from django.test import SimpleTestCase

from .offline_capture_fence import (
    verify_capture_fence,
    CaptureConsistencyError,
)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class B06CaptureFenceTests(SimpleTestCase):
    def setUp(self):
        self.identifier = uuid.uuid4().hex

        self.db = {
            self.identifier: sha(b"encrypted synthetic bytes")
        }

        digest = sha(
            json.dumps(
                self.db,
                sort_keys=True,
                separators=(",", ":"),
            ).encode()
        )

        self.before = {
            "epoch": 4,
            "snapshot": "synthetic-pg17-v1",
            "inventory_digest": digest,
        }

        self.after = dict(self.before)
        self.objects = dict(self.db)

    def check(self, **overrides):
        args = dict(
            before=self.before,
            after=self.after,
            database_inventory=self.db,
            object_inventory=self.objects,
        )
        args.update(overrides)
        return verify_capture_fence(**args)

    def test_matching_capture(self):
        result = self.check()
        self.assertTrue(result["consistent"])
        self.assertFalse(result["release_authorized"])

    def test_epoch_changed(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(after={
                **self.after,
                "epoch": 5,
            })

    def test_snapshot_changed(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(after={
                **self.after,
                "snapshot": "different-pg17",
            })

    def test_object_modified(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(object_inventory={
                self.identifier: "0" * 64
            })

    def test_object_missing(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(object_inventory={})

    def test_extra_object(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(object_inventory={
                **self.objects,
                uuid.uuid4().hex: "0" * 64,
            })

    def test_bad_inventory_marker(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(before={
                **self.before,
                "inventory_digest": "0" * 64,
            })

    def test_invalid_epoch(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(before={
                **self.before,
                "epoch": -1,
            })

    def test_boolean_epoch_rejected(self):
        with self.assertRaises(CaptureConsistencyError):
            self.check(before={
                **self.before,
                "epoch": True,
            })

    def test_empty_inventory_allowed_with_matching_marker(self):
        empty_digest = sha(b"{}")
        marker = {
            "epoch": 0,
            "snapshot": "empty-snapshot",
            "inventory_digest": empty_digest,
        }

        result = self.check(
            before=marker,
            after=marker.copy(),
            database_inventory={},
            object_inventory={},
        )
        self.assertEqual(result["objects"], 0)
        self.assertFalse(result["release_authorized"])
