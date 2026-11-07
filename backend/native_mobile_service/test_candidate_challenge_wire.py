"""Contract-level proof only: no DB row, MFA decision or token issuer."""
import unittest
import uuid
from unittest.mock import patch

from .candidate_challenge_wire import (
    NativeChallengeMalformed, matches_candidate_digest,
    new_candidate_challenge, parse_candidate_challenge,
)


@patch.dict("os.environ", {"VENCIRA_ENV": "test", "VENCIRA_NATIVE_SERVICE_CANDIDATE": "1"})
class CandidateChallengeWireTests(unittest.TestCase):
    def test_generating_outside_explicit_lab_is_denied(self):
        for environment, candidate in [("production", "1"), ("development", "1"), ("test", "0")]:
            with self.subTest(environment=environment, candidate=candidate), patch.dict(
                "os.environ", {"VENCIRA_ENV": environment, "VENCIRA_NATIVE_SERVICE_CANDIDATE": candidate}
            ):
                with self.assertRaises(NativeChallengeMalformed):
                    new_candidate_challenge()

    def test_random_secret_matches_flutter_lc1_shape(self):
        wire, challenge_id, digest = new_candidate_challenge()
        self.assertRegex(wire, r"^lc1\.[0-9a-f]{32}\.[A-Za-z0-9_-]{43}$")
        self.assertEqual(len(digest), 64)
        parsed_id, secret = parse_candidate_challenge(wire)
        self.assertEqual(parsed_id, challenge_id)
        self.assertEqual(len(secret), 32)
        self.assertTrue(matches_candidate_digest(
            wire, expected_id=challenge_id, stored_digest=digest))

    def test_fresh_challenges_are_independent(self):
        first, first_id, first_digest = new_candidate_challenge()
        second, second_id, second_digest = new_candidate_challenge()
        self.assertNotEqual(first, second)
        self.assertNotEqual(first_id, second_id)
        self.assertNotEqual(first_digest, second_digest)
        self.assertFalse(matches_candidate_digest(
            first, expected_id=second_id, stored_digest=second_digest))

    def test_digest_only_rejects_wrong_uuid_digest_and_secret(self):
        wire, cid, digest = new_candidate_challenge()
        self.assertFalse(matches_candidate_digest(
            wire, expected_id=uuid.uuid4(), stored_digest=digest))
        self.assertFalse(matches_candidate_digest(
            wire, expected_id=cid, stored_digest="0" * 64))
        self.assertFalse(matches_candidate_digest(
            wire, expected_id=cid, stored_digest="NOT A DIGEST"))
        other, _, _ = new_candidate_challenge()
        changed_secret = wire[:37] + other[37:]
        self.assertFalse(matches_candidate_digest(
            changed_secret, expected_id=cid, stored_digest=digest))

    def test_noncanonical_and_bad_length_fail_closed(self):
        wire, cid, digest = new_candidate_challenge()
        invalid = [
            "", None, 123, " " + wire, wire + " ", wire + "=", wire.upper(),
            wire.replace("lc1.", "lc2."), wire.replace("lc1.", "lc1.."),
            wire[:10], "lc1." + cid.hex + "." + ("a" * 43),
            "lc1." + cid.hex.upper() + "." + wire.split(".")[2],
        ]
        for value in invalid:
            with self.subTest(value=str(value)[:30]), self.assertRaises(
                NativeChallengeMalformed
            ):
                parse_candidate_challenge(value)
        self.assertTrue(matches_candidate_digest(
            wire, expected_id=cid, stored_digest=digest))

    def test_bad_expected_metadata_cannot_match(self):
        wire, cid, digest = new_candidate_challenge()
        for expected_id, stored in [(str(cid), digest), (cid, None),
                                    (cid, digest.upper()), (None, digest)]:
            with self.subTest(expected_id=expected_id, stored=stored):
                self.assertFalse(matches_candidate_digest(
                    wire, expected_id=expected_id, stored_digest=stored))
