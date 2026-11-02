"""Synthetic N1 opaque token tests; no HTTP route or real secret is used."""
import uuid

from django.test import SimpleTestCase, override_settings

from .native_mobile_token_primitives import (
    NativeMobileTokenInvalid,
    make_native_token, matches_native_token,
    native_token_digest, parse_native_token,
)


class NativeOpaqueTokenTests(SimpleTestCase):
    def setUp(self):
        self.session_id = uuid.uuid4()

    def test_access_and_refresh_are_random_and_256_bit(self):
        first = make_native_token(kind="a", session_id=self.session_id)
        second = make_native_token(kind="a", session_id=self.session_id)
        refresh = make_native_token(kind="r", session_id=self.session_id)
        self.assertNotEqual(first, second)
        self.assertNotEqual(first, refresh)
        self.assertEqual(parse_native_token(first, kind="a"), self.session_id)
        self.assertEqual(parse_native_token(refresh, kind="r"), self.session_id)

    def test_access_cannot_be_used_as_refresh_or_vice_versa(self):
        access = make_native_token(kind="a", session_id=self.session_id)
        refresh = make_native_token(kind="r", session_id=self.session_id)
        for raw, kind in ((access, "r"), (refresh, "a")):
            with self.subTest(kind=kind), self.assertRaises(NativeMobileTokenInvalid):
                parse_native_token(raw, kind=kind)

    def test_digest_matches_only_original_token(self):
        access = make_native_token(kind="a", session_id=self.session_id)
        other = make_native_token(kind="a", session_id=self.session_id)
        digest = native_token_digest(access, kind="a")
        self.assertEqual(len(digest), 64)
        self.assertTrue(matches_native_token(
            access, kind="a", stored_digest=digest,
        ))
        self.assertFalse(matches_native_token(
            other, kind="a", stored_digest=digest,
        ))

    def test_token_cannot_be_authenticated_by_lookup_uuid(self):
        access = make_native_token(kind="a", session_id=self.session_id)
        digest = native_token_digest(access, kind="a")
        impostor = make_native_token(kind="a", session_id=self.session_id)
        self.assertEqual(
            parse_native_token(impostor, kind="a"), self.session_id,
        )
        self.assertFalse(matches_native_token(
            impostor, kind="a", stored_digest=digest,
        ))

    def test_rejects_noncanonical_and_malformed_token_shapes(self):
        access = make_native_token(kind="a", session_id=self.session_id)
        cases = (
            access + "=",
            access + " ",
            access + "\n",
            access.replace("v1.a.", "v1.b."),
            access.replace("v1.a.", "v1.a.."),
            access.upper(),
            access[:-1] + "B",
            "",
        )
        for token in cases:
            with self.subTest(case_len=len(token)):
                with self.assertRaises(NativeMobileTokenInvalid):
                    parse_native_token(token, kind="a")
        with self.assertRaises(NativeMobileTokenInvalid):
            parse_native_token(None, kind="a")

    def test_rejects_unknown_kind_and_invalid_session_identity(self):
        for kind in ("", "z", "a "):
            with self.subTest(kind=kind), self.assertRaises(NativeMobileTokenInvalid):
                make_native_token(kind=kind, session_id=self.session_id)
        with self.assertRaises(NativeMobileTokenInvalid):
            make_native_token(kind="a", session_id=str(self.session_id))

    def test_digest_domain_and_key_are_isolated(self):
        a = make_native_token(kind="a", session_id=self.session_id)
        with override_settings(SECRET_KEY="test-only-n1-key-a-123456789012345"):
            digest_a = native_token_digest(a, kind="a")
        with override_settings(SECRET_KEY="test-only-n1-key-b-123456789012345"):
            digest_b = native_token_digest(a, kind="a")
        self.assertNotEqual(digest_a, digest_b)

    def test_malformed_stored_digest_denied(self):
        access = make_native_token(kind="a", session_id=self.session_id)
        for bad in ("", "0" * 63, "0" * 65, "Z" * 64, None):
            with self.subTest(length=len(bad) if bad is not None else -1):
                self.assertFalse(matches_native_token(
                    access, kind="a", stored_digest=bad,
                ))
