from django.test import SimpleTestCase
from .offline_pending_intent_reconcile_b18l import classify_pending_intent

class B18LPendingIntentTests(SimpleTestCase):
    def assert_blocked(self, expected, **flags):
        result = classify_pending_intent(**flags)
        self.assertEqual(result.classification, expected)
        self.assertTrue(result.requires_manual_review)
        self.assertFalse(result.release_authorized)
        self.assertFalse(result.delete_authorized)

    def test_failed_object_write_retains_pending_intent(self):
        self.assert_blocked("ORPHAN_PENDING_INTENT", journal_present=True,
                            object_present=False, metadata_present=False)

    def test_failed_metadata_write_preserves_object_for_review(self):
        self.assert_blocked("ORPHAN_ENCRYPTED_OBJECT", journal_present=True,
                            object_present=True, metadata_present=False,
                            object_digest_matches=True)

    def test_metadata_without_object(self):
        self.assert_blocked("METADATA_WITHOUT_OBJECT", journal_present=True,
                            object_present=False, metadata_present=True)

    def test_complete_pair_with_pending_intent_still_needs_review(self):
        self.assert_blocked("PENDING_INTENT_WITH_COMPLETE_PAIR", journal_present=True,
                            object_present=True, metadata_present=True,
                            object_digest_matches=True)

    def test_missing_journal(self):
        self.assert_blocked("MISSING_JOURNAL_EVIDENCE", journal_present=False,
                            object_present=True, metadata_present=True,
                            object_digest_matches=True)

    def test_missing_digest_proof(self):
        self.assert_blocked("OBJECT_DIGEST_UNVERIFIED", journal_present=True,
                            object_present=True, metadata_present=False)

    def test_wrong_digest(self):
        self.assert_blocked("OBJECT_DIGEST_UNVERIFIED", journal_present=True,
                            object_present=True, metadata_present=True,
                            object_digest_matches=False)

    def test_invalid_flags(self):
        with self.assertRaises(ValueError):
            classify_pending_intent(journal_present=1, object_present=False,
                                    metadata_present=False)
