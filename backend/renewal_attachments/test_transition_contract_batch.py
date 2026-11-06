"""Offline security regression for the pure attachment inventory transition."""
import unittest
from datetime import datetime, timezone
from uuid import uuid4
from renewal_attachments.transition_contract import compare_inventories

class TransitionContractTests(unittest.TestCase):
    def row(self, **changes):
        r = dict(id=uuid4(), renewal_id=uuid4(), uploaded_by_id=None,
                 display_name="synthetic", content_type="application/pdf",
                 byte_size=5, sha256="a" * 64, storage_key=uuid4(),
                 state="quarantined",
                 created_at=datetime(2026, 1, 1, tzinfo=timezone.utc))
        r.update(changes)
        return r

    def test_empty_is_only_empty_not_release(self):
        result = compare_inventories([], [])
        self.assertEqual(result["legacy_count"], 0)
        self.assertEqual(result["independent_count"], 0)
        self.assertNotIn("release_authorized", result)

    def test_matching_metadata(self):
        a = self.row()
        self.assertEqual(compare_inventories([a], [a])["conflicting_records"], 0)

    def test_legacy_only(self):
        self.assertEqual(compare_inventories([self.row()], [])["missing_in_independent"], 1)

    def test_independent_only(self):
        self.assertEqual(compare_inventories([], [self.row()])["missing_in_legacy"], 1)

    def test_created_at_mismatch(self):
        a = self.row()
        b = dict(a, created_at=datetime(2026, 2, 1, tzinfo=timezone.utc))
        self.assertEqual(compare_inventories([a], [b])["conflicting_records"], 1)

    def test_digest_mismatch(self):
        a = self.row()
        self.assertEqual(compare_inventories([a], [dict(a, sha256="b" * 64)])["conflicting_records"], 1)

    def test_storage_key_reused_between_ids(self):
        a = self.row()
        b = self.row(storage_key=a["storage_key"])
        self.assertEqual(compare_inventories([a], [b])["reused_storage_keys"], 1)

    def test_duplicate_storage_key_same_side_fails(self):
        a = self.row()
        b = self.row(storage_key=a["storage_key"])
        with self.assertRaisesRegex(ValueError, "DUPLICATE_STORAGE_KEYS"):
            compare_inventories([a, b], [])

    def test_duplicate_ids_same_side_fails(self):
        a = self.row()
        with self.assertRaisesRegex(ValueError, "DUPLICATE_IDS"):
            compare_inventories([a, dict(a)], [])

    def test_malformed_inventory_fails(self):
        a = self.row()
        del a["byte_size"]
        with self.assertRaisesRegex(ValueError, "INVENTORY_SHAPE"):
            compare_inventories([a], [])

    def test_null_storage_key_fails(self):
        with self.assertRaisesRegex(ValueError, "NULL_ID_OR_KEY"):
            compare_inventories([self.row(storage_key=None)], [])

if __name__ == "__main__":
    unittest.main()
