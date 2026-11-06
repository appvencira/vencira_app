"""G5 network attribution tests; stdlib only, no database or secrets."""
import unittest

from .g5_network_identity import (
    UntrustedNetworkIdentity, candidate_client_ip,
)


class G5NetworkIdentityTests(unittest.TestCase):
    def test_direct_client_cannot_spoof_forwarded_headers(self):
        self.assertEqual(candidate_client_ip({
            "REMOTE_ADDR": "198.51.100.10",
            "HTTP_X_FORWARDED_FOR": "203.0.113.44",
            "HTTP_FORWARDED": "for=203.0.113.45",
        }, trusted_proxy_ips=("192.0.2.1",)), "198.51.100.10")

    def test_explicit_proxy_single_hop(self):
        self.assertEqual(candidate_client_ip({
            "REMOTE_ADDR": "192.0.2.1",
            "HTTP_X_FORWARDED_FOR": "2001:db8::5",
        }, trusted_proxy_ips=("192.0.2.1",)), "2001:db8::5")

    def test_ipv4_mapped_peer_normalized(self):
        self.assertEqual(candidate_client_ip({
            "REMOTE_ADDR": "::ffff:192.0.2.1",
            "HTTP_X_FORWARDED_FOR": "203.0.113.8",
        }, trusted_proxy_ips=("192.0.2.1",)), "203.0.113.8")

    def test_untrusted_ipv6_direct(self):
        self.assertEqual(candidate_client_ip({
            "REMOTE_ADDR": "2001:db8::a",
            "HTTP_X_FORWARDED_FOR": "192.0.2.2",
        }), "2001:db8::a")

    def test_invalid_remote_peer_always_denied(self):
        for invalid in ("", "192.0.2.1, 203.0.113.9", "192.0.2.1 ", None):
            with self.subTest(invalid=invalid):
                with self.assertRaises(UntrustedNetworkIdentity):
                    candidate_client_ip({"REMOTE_ADDR": invalid})

    def test_proxy_rejects_missing_or_ambiguous_forwarded(self):
        samples = (
            {},
            {"HTTP_X_FORWARDED_FOR": ""},
            {"HTTP_X_FORWARDED_FOR": "192.0.2.9, 203.0.113.9"},
            {"HTTP_X_FORWARDED_FOR": "not-an-ip"},
            {"HTTP_X_FORWARDED_FOR": "203.0.113.9 "},
            {"HTTP_X_FORWARDED_FOR": "192.0.2.1"},
            {"HTTP_X_FORWARDED_FOR": "203.0.113.9", "HTTP_FORWARDED": "for=1.2.3.4"},
        )
        for extra in samples:
            with self.subTest(extra=extra):
                with self.assertRaises(UntrustedNetworkIdentity):
                    candidate_client_ip({
                        "REMOTE_ADDR": "192.0.2.1", **extra,
                    }, trusted_proxy_ips=("192.0.2.1",))

    def test_malformed_proxy_allowlist_rejected(self):
        with self.assertRaises(UntrustedNetworkIdentity):
            candidate_client_ip({"REMOTE_ADDR": "192.0.2.1"},
                                trusted_proxy_ips=("0.0.0.0/0",))


if __name__ == "__main__":
    unittest.main()
