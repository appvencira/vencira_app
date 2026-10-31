"""Pure conservative HBA trust-scope tests; no SQL, Docker or secrets."""
import unittest
from scripts.audit_mb1_m103_host_trust_scope_readonly import scope, classify


class HostTrustScopeTests(unittest.TestCase):
    def test_ipv4_loopback_cidr(self):
        self.assertEqual(scope("127.0.0.1","255.255.255.255"),"LOOPBACK_IPV4")

    def test_ipv6_loopback_cidr(self):
        self.assertEqual(scope("::1","128"),"LOOPBACK_IPV6")

    def test_ipv6_expanded_hex_netmask_loopback(self):
        self.assertEqual(scope("::1","ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"),"LOOPBACK_IPV6")

    def test_noncontiguous_ipv6_mask_not_trusted(self):
        self.assertEqual(scope("::1","ffff:0:ffff::"),"UNRESOLVED")

    def test_all_ipv4_is_not_loopback(self):
        self.assertEqual(scope("0.0.0.0","0.0.0.0"),"NONLOOPBACK")

    def test_all_ipv6_is_not_loopback(self):
        self.assertEqual(scope("::","0"),"NONLOOPBACK")

    def test_private_docker_network_is_not_loopback(self):
        self.assertEqual(scope("172.18.0.0","16"),"NONLOOPBACK")

    def test_hostname_not_certified_as_loopback(self):
        self.assertEqual(scope("localhost",None),"UNRESOLVED")

    def test_samehost_requires_manual_check(self):
        self.assertEqual(scope("samehost",None),"UNRESOLVED")

    def test_null_address_requires_review(self):
        self.assertEqual(scope(None,None),"UNRESOLVED")

    def test_aggregate_reconciles_all_host_trust_rules(self):
        got=classify([
          {"address":"127.0.0.1","mask":"255.255.255.255"},
          {"address":"::1","mask":"128"},
          {"address":"172.19.0.0","mask":"16"},
          {"address":"samehost","mask":None},
        ])
        self.assertEqual(got,{"LOOPBACK_IPV4":1,"LOOPBACK_IPV6":1,
                              "NONLOOPBACK":1,"UNRESOLVED":1})

    def test_unexpected_row_keys_abort(self):
        with self.assertRaises(ValueError):
            classify([{"address":"127.0.0.1","mask":None,"secret":"x"}])


if __name__ == "__main__":
    unittest.main()
