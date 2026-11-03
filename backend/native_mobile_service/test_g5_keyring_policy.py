"""G5 keyring policy tests; synthetic 256-bit materials, no Django setup."""
from datetime import datetime, timedelta, timezone
import unittest

from .g5_keyring_policy import (
    CandidateKey, CandidateKeyDenied, CandidateKeyring,
)


class G5KeyringPolicyTests(unittest.TestCase):
    def setUp(self):
        self.old = CandidateKey("old", b"o" * 32)
        self.new = CandidateKey("new", b"n" * 32)
        self.cutoff = datetime(2030, 1, 1, tzinfo=timezone.utc)

    def test_active_key_and_purpose_separation(self):
        ring = CandidateKeyring(active=self.new)
        value = b"synthetic-token"
        saved = ring.digest(purpose="mobile-refresh", value=value)
        self.assertTrue(ring.verify(purpose="mobile-refresh", value=value, stored=saved))
        self.assertFalse(ring.verify(purpose="mobile-access", value=value, stored=saved))
        self.assertFalse(ring.verify(purpose="mobile-refresh", value=b"different", stored=saved))
        self.assertTrue(saved.startswith("k1:new:"))

    def test_rotation_keeps_bounded_verification_only(self):
        oldring = CandidateKeyring(active=self.old)
        saved = oldring.digest(purpose="mobile-access", value=b"secret")
        rotation = CandidateKeyring(
            active=self.new,
            previous=(CandidateKey("old", b"o" * 32, verify_until=self.cutoff),),
        )
        self.assertTrue(rotation.verify(
            purpose="mobile-access", value=b"secret", stored=saved,
            now=self.cutoff - timedelta(seconds=1),
        ))
        self.assertFalse(rotation.verify(
            purpose="mobile-access", value=b"secret", stored=saved,
            now=self.cutoff,
        ))
        self.assertTrue(rotation.digest(
            purpose="mobile-access", value=b"secret",
        ).startswith("k1:new:"))

    def test_unknown_key_or_legacy_digest_rejected(self):
        ring = CandidateKeyring(active=self.new)
        self.assertFalse(ring.verify(
            purpose="mobile-access", value=b"x", stored="0" * 64,
        ))
        self.assertFalse(ring.verify(
            purpose="mobile-access", value=b"x",
            stored="k1:unknown:" + "0" * 64,
        ))

    def test_duplicate_ids_and_material_denied(self):
        with self.assertRaises(CandidateKeyDenied):
            CandidateKeyring(
                active=self.new,
                previous=(CandidateKey("new", b"x" * 32, verify_until=self.cutoff),),
            )
        with self.assertRaises(CandidateKeyDenied):
            CandidateKeyring(
                active=self.new,
                previous=(CandidateKey("prior", b"n" * 32, verify_until=self.cutoff),),
            )

    def test_predecessor_without_expiry_is_denied(self):
        with self.assertRaises(CandidateKeyDenied):
            CandidateKeyring(active=self.new, previous=(self.old,))

    def test_active_cannot_be_expiring_verification_key(self):
        with self.assertRaises(CandidateKeyDenied):
            CandidateKeyring(active=CandidateKey(
                "x", b"x" * 32, verify_until=self.cutoff,
            ))

    def test_malformed_or_short_key_denied(self):
        for identifier in ("", "UPPER", "a.b", "a" * 21):
            with self.subTest(identifier=identifier):
                with self.assertRaises(CandidateKeyDenied):
                    CandidateKey(identifier, b"x" * 32)
        with self.assertRaises(CandidateKeyDenied):
            CandidateKey("short", b"x" * 16)

    def test_unknown_purpose_and_empty_payload_denied(self):
        ring = CandidateKeyring(active=self.new)
        with self.assertRaises(CandidateKeyDenied):
            ring.digest(purpose="other", value=b"value")
        with self.assertRaises(CandidateKeyDenied):
            ring.digest(purpose="mobile-audit", value=b"")

    def test_no_naive_expiration_or_clock(self):
        with self.assertRaises(CandidateKeyDenied):
            CandidateKey("old", b"x" * 32, verify_until=datetime(2030, 1, 1))
        ring = CandidateKeyring(active=self.new)
        saved = ring.digest(purpose="mobile-audit", value=b"a")
        with self.assertRaises(CandidateKeyDenied):
            ring.verify(
                purpose="mobile-audit", value=b"a", stored=saved,
                now=datetime(2030, 1, 1),
            )


if __name__ == "__main__":
    unittest.main()
