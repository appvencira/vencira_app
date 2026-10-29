import json
from datetime import date, timedelta

from django.test import SimpleTestCase

from .offline_backup_manifest_b09 import (
    BackupManifestError, create_manifest,
    verify_manifest, plan_retention
)


class B09ManifestTests(SimpleTestCase):
    def setUp(self):
        self.db = b"database encrypted synthetic"
        self.files = b"attachments encrypted synthetic"
        self.key = b"k" * 32
        self.manifest = create_manifest(
            database_envelope=self.db,
            attachment_bundle=self.files,
            snapshot_id="capture-001",
            database_key_id="database-v1",
            attachment_key_id="attachment-v1",
            manifest_key_id="manifest-v1",
            authentication_key=self.key,
        )

    def check(self, **changes):
        args = {
            "manifest": self.manifest,
            "database_envelope": self.db,
            "attachment_bundle": self.files,
            "expected_snapshot_id": "capture-001",
            "expected_database_key_id": "database-v1",
            "expected_attachment_key_id": "attachment-v1",
            "expected_manifest_key_id": "manifest-v1",
            "authentication_key": self.key,
        }
        args.update(changes)
        return verify_manifest(**args)

    def test_success_never_authorizes_release(self):
        result = self.check()
        self.assertTrue(result["verified"])
        self.assertFalse(result["release_authorized"])

    def test_wrong_authentication_key(self):
        with self.assertRaises(BackupManifestError):
            self.check(authentication_key=b"x" * 32)

    def test_wrong_snapshot(self):
        with self.assertRaises(BackupManifestError):
            self.check(expected_snapshot_id="capture-002")

    def test_wrong_key_version(self):
        with self.assertRaises(BackupManifestError):
            self.check(expected_database_key_id="database-v2")

    def test_db_replaced(self):
        with self.assertRaises(BackupManifestError):
            self.check(database_envelope=b"other database")

    def test_bundle_replaced(self):
        with self.assertRaises(BackupManifestError):
            self.check(attachment_bundle=b"other files")

    def test_manifest_modified(self):
        data = json.loads(self.manifest)
        data["payload"]["snapshot_id"] = "capture-002"
        with self.assertRaises(BackupManifestError):
            self.check(manifest=json.dumps(data).encode())

    def test_empty_objects_rejected(self):
        with self.assertRaises(BackupManifestError):
            create_manifest(
                database_envelope=b"",
                attachment_bundle=self.files,
                snapshot_id="capture-001",
                database_key_id="database-v1",
                attachment_key_id="attachment-v1",
                manifest_key_id="manifest-v1",
                authentication_key=self.key,
            )

    def test_short_key_rejected(self):
        with self.assertRaises(BackupManifestError):
            self.check(authentication_key=b"short")

    def test_cross_manifest_mismatch(self):
        other = create_manifest(
            database_envelope=b"other",
            attachment_bundle=self.files,
            snapshot_id="capture-001",
            database_key_id="database-v1",
            attachment_key_id="attachment-v1",
            manifest_key_id="manifest-v1",
            authentication_key=self.key,
        )
        with self.assertRaises(BackupManifestError):
            self.check(manifest=other)


class B09RetentionTests(SimpleTestCase):
    def setUp(self):
        self.today = date(2026, 10, 29)

    def snapshot(self, name, age, good=True):
        return {
            "id": name,
            "created_on": self.today - timedelta(days=age),
            "verified": good,
            "recoverable": good,
        }

    def test_retention_is_never_destructive(self):
        result = plan_retention(
            snapshots=[
                self.snapshot("new", 1),
                self.snapshot("middle", 35),
                self.snapshot("old", 90)
            ],
            today=self.today,
        )
        self.assertFalse(result["deletion_authorized"])
        self.assertEqual(result["retain"], ["new", "middle"])
        self.assertEqual(
            result["eligible_for_manual_review"], ["old"]
        )

    def test_less_than_minimum_preserves_everything(self):
        result = plan_retention(
            snapshots=[
                self.snapshot("only", 60),
                self.snapshot("bad", 90, good=False),
            ],
            today=self.today,
        )
        self.assertEqual(
            result["eligible_for_manual_review"], []
        )
        self.assertEqual(set(result["retain"]), {"only", "bad"})

    def test_bad_snapshot_never_deleted(self):
        result = plan_retention(
            snapshots=[
                self.snapshot("new", 1),
                self.snapshot("other", 2),
                self.snapshot("corrupt", 120, good=False),
            ],
            today=self.today,
        )
        self.assertIn("corrupt", result["retain"])

    def test_duplicate_ids_rejected(self):
        with self.assertRaises(BackupManifestError):
            plan_retention(
                snapshots=[
                    self.snapshot("same", 1),
                    self.snapshot("same", 2),
                ],
                today=self.today,
            )

    def test_future_date_rejected(self):
        with self.assertRaises(BackupManifestError):
            plan_retention(
                snapshots=[self.snapshot("future", -1)],
                today=self.today,
            )

    def test_no_snapshots(self):
        result = plan_retention(snapshots=[], today=self.today)
        self.assertTrue(result["requires_review"])
        self.assertEqual(result["eligible_for_manual_review"], [])

    def test_older_two_always_protected(self):
        result = plan_retention(
            snapshots=[
                self.snapshot("a", 100),
                self.snapshot("b", 110),
                self.snapshot("c", 120),
            ],
            today=self.today,
        )
        self.assertEqual(set(result["retain"]), {"a", "b"})
        self.assertFalse(result["deletion_authorized"])
