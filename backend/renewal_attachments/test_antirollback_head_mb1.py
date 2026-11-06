"""Pure synthetic tests; no Django, Docker, filesystem, services or real keys."""
import hashlib
import json
import unittest

from renewal_attachments.offline_antirollback_head_mb1 import (
    AntiRollbackError, make_genesis, issue_successor,
    verify_successor, verify_restore, verify_receipt,
)


class MB1IndependentTrustedHeadTests(unittest.TestCase):
    def setUp(self):
        self.key = b"synthetic-independent-receipt-key-000001"
        self.first_package = b"synthetic-encrypted-package-A"
        self.second_package = b"synthetic-encrypted-package-B"
        self.genesis = make_genesis("snapshot-A", self.first_package, self.key)
        self.second = issue_successor(
            self.genesis, "snapshot-B", self.second_package, self.key
        )

    def test_current_independent_head_permits_only_matching_package(self):
        result = verify_restore(self.second, self.second, self.second_package, self.key)
        self.assertEqual(result["sequence"], 2)
        self.assertFalse(result["release_authorized"])

    def test_valid_signed_old_backup_rejected_against_newer_external_head(self):
        with self.assertRaisesRegex(AntiRollbackError, "STALE_OR_UNTRUSTED_SNAPSHOT"):
            verify_restore(self.second, self.genesis, self.first_package, self.key)

    def test_successor_is_monotonic_and_linked_to_trusted_head(self):
        result = verify_successor(self.genesis, self.second, self.key)
        self.assertEqual(result["sequence"], 2)
        with self.assertRaisesRegex(AntiRollbackError, "INVALID_CHAIN_CONTINUATION"):
            verify_successor(self.second, self.genesis, self.key)

    def test_arbitrary_valid_signed_next_candidate_cannot_be_restored_before_external_promotion(self):
        with self.assertRaisesRegex(AntiRollbackError, "STALE_OR_UNTRUSTED_SNAPSHOT"):
            verify_restore(self.genesis, self.second, self.second_package, self.key)

    def test_swapped_package_fails_even_with_correct_receipt(self):
        with self.assertRaisesRegex(AntiRollbackError, "PACKAGE_DIGEST_MISMATCH"):
            verify_restore(self.second, self.second, self.first_package, self.key)

    def test_hmac_mutation_rejected(self):
        record = json.loads(self.second)
        record["payload"]["snapshot_id"] = "snapshot-evil"
        tampered = json.dumps(
            record, sort_keys=True, separators=(",", ":")
        ).encode()
        with self.assertRaisesRegex(AntiRollbackError, "UNAUTHENTICATED_RECEIPT"):
            verify_receipt(tampered, self.key)

    def test_wrong_receipt_key_rejected(self):
        with self.assertRaises(AntiRollbackError):
            verify_restore(self.second, self.second, self.second_package, b"x" * 32)

    def test_noncanonical_receipt_rejected(self):
        noncanonical = json.dumps(json.loads(self.second)).encode()
        with self.assertRaisesRegex(AntiRollbackError, "NONCANONICAL_RECEIPT"):
            verify_receipt(noncanonical, self.key)

    def test_missing_independent_head_fails_closed(self):
        with self.assertRaises(AntiRollbackError):
            verify_restore(None, self.second, self.second_package, self.key)

    def test_duplicate_json_fields_rejected(self):
        duplicate = self.second.replace(b'"payload":', b'"payload":{},"payload":', 1)
        with self.assertRaisesRegex(AntiRollbackError, "DUPLICATE_JSON_FIELD"):
            verify_receipt(duplicate, self.key)

    def test_genesis_requires_explicit_zero_link(self):
        first = verify_receipt(self.genesis, self.key)
        self.assertEqual(first["previous_receipt_sha256"], "0" * 64)
        second = verify_receipt(self.second, self.key)
        self.assertEqual(
            second["previous_receipt_sha256"],
            hashlib.sha256(self.genesis).hexdigest(),
        )


if __name__ == "__main__":
    unittest.main()
