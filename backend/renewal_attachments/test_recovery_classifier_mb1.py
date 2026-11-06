import unittest
from uuid import UUID

from .offline_recovery_classifier_mb1 import (
    ReconciliationBlocked, classify_recovery_inventory,
)


class MB1ClassifierTests(unittest.TestCase):
    def key(self, i):
        return UUID(int=i)

    def classify(self, i=(), o=(), m=()):
        return classify_recovery_inventory(
            intents={self.key(n) for n in i},
            objects={self.key(n) for n in o},
            metadata={self.key(n) for n in m},
        )

    def test_empty(self):
        result = self.classify()
        self.assertFalse(result["requires_review"])
        self.assertFalse(result["release_authorized"])

    def test_complete_never_authorizes_release(self):
        result = self.classify([1], [1], [1])
        self.assertEqual(result["complete"], 1)
        self.assertFalse(result["content_verified"])
        self.assertFalse(result["consistent_snapshot_verified"])

    def test_intent_only(self):
        r = self.classify([1])
        self.assertEqual(r["intent_only"], 1)
        self.assertEqual(r["intent_without_object"], 1)
        self.assertTrue(r["requires_review"])

    def test_object_only(self):
        r = self.classify(o=[1])
        self.assertEqual(r["object_only"], 1)
        self.assertEqual(r["object_without_metadata"], 1)

    def test_metadata_only(self):
        r = self.classify(m=[1])
        self.assertEqual(r["metadata_only"], 1)
        self.assertEqual(r["metadata_without_object"], 1)

    def test_intent_and_object_without_metadata(self):
        r = self.classify([1], [1])
        self.assertEqual(r["intent_and_object_without_metadata"], 1)
        self.assertFalse(r["repair_authorized"])

    def test_object_and_metadata_without_intent(self):
        r = self.classify(o=[1], m=[1])
        self.assertEqual(r["object_and_metadata_without_intent"], 1)

    def test_intent_and_metadata_without_object(self):
        r = self.classify(i=[1], m=[1])
        self.assertEqual(r["intent_and_metadata_without_object"], 1)

    def test_all_states_distinct_and_counted_once(self):
        r = self.classify(
            i=[1, 2, 4, 6],
            o=[1, 3, 4, 5],
            m=[1, 5, 6, 7],
        )
        self.assertEqual(r["total_keys"], 7)
        self.assertEqual(r["complete"], 1)
        for name in (
            "intent_only", "object_only", "metadata_only",
            "intent_and_object_without_metadata",
            "object_and_metadata_without_intent",
            "intent_and_metadata_without_object",
        ):
            self.assertEqual(r[name], 1)
        self.assertFalse(r["deletion_authorized"])

    def test_invalid_fails_closed(self):
        with self.assertRaises(ReconciliationBlocked):
            classify_recovery_inventory(
                intents={"not-uuid"}, objects=set(), metadata=set()
            )
        with self.assertRaises(ReconciliationBlocked):
            classify_recovery_inventory(
                intents=[], objects=set(), metadata=set()
            )


if __name__ == "__main__":
    unittest.main()
