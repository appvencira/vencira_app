"""D1.5a — Vectores públicos RFC 6238 y defensas TOTP."""
import base64
from urllib.parse import parse_qs, urlparse

from django.test import SimpleTestCase

from .mfa_totp import generate_secret, match_counter, provisioning_uri, totp_at


class TotpPrimitiveTests(SimpleTestCase):
    def test_rfc_6238_sha1_vectors_eight_digits(self):
        # RFC 6238 Appendix B (SHA-1, seed ASCII de 20 bytes).
        secret = base64.b32encode(b"12345678901234567890").decode("ascii")
        expected = [
            (59, "94287082"),
            (1111111109, "07081804"),
            (1111111111, "14050471"),
            (1234567890, "89005924"),
            (2000000000, "69279037"),
            (20000000000, "65353130"),
        ]
        for timestamp, code in expected:
            with self.subTest(timestamp=timestamp):
                self.assertEqual(totp_at(secret, timestamp, digits=8), code)

    def test_random_secret_strength_and_unique(self):
        first, second = generate_secret(), generate_secret()
        self.assertNotEqual(first, second)
        self.assertEqual(len(base64.b32decode(first)), 20)
        self.assertEqual(len(base64.b32decode(second)), 20)

    def test_code_format_window_and_replay_gate(self):
        secret = generate_secret()
        current = 300_000
        current_code = totp_at(secret, current)
        counter = current // 30
        self.assertEqual(match_counter(secret, current_code, timestamp=current), counter)
        self.assertIsNone(match_counter(secret, current_code,
                                        timestamp=current, last_accepted_counter=counter))
        self.assertEqual(match_counter(secret, current_code, timestamp=current + 30, window=1), counter)
        self.assertIsNone(match_counter(secret, current_code, timestamp=current + 60, window=1))
        for invalid in ("", "12345", "1234567", "a23456", "１２３４５６", "123 56"):
            with self.subTest(invalid=invalid):
                self.assertIsNone(match_counter(secret, invalid, timestamp=current))

    def test_provisioning_uri_escapes_label_and_has_standard_parameters(self):
        uri = provisioning_uri(generate_secret(), "agente+demo@example.test")
        parsed = urlparse(uri)
        params = parse_qs(parsed.query)
        self.assertEqual(parsed.scheme, "otpauth")
        self.assertEqual(parsed.netloc, "totp")
        self.assertEqual(params["issuer"], ["VENCIRA"])
        self.assertEqual(params["period"], ["30"])
        self.assertEqual(params["digits"], ["6"])
        self.assertEqual(params["algorithm"], ["SHA1"])
        self.assertIn("agente%2Bdemo%40example.test", parsed.path)

    def test_reject_short_or_invalid_secret(self):
        for invalid in ("", "AA", "abc$", "O0000000000000000000"):
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError):
                    totp_at(invalid, 59)
