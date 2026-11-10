"""Unit regression for D1-Y structural Caddy host-scoped proxy analysis."""
import unittest

from main_d1y_caddy_dev_route_readonly import visit_routes


class D1YHostScopedProxyTests(unittest.TestCase):
    def test_explicit_dev_host_and_reverse_proxy(self):
        routes = [{"match": [{"host": ["dev.vencira.es"]}],
                   "handle": [{"handler": "reverse_proxy"}]}]
        self.assertEqual(visit_routes(routes), (True, True))

    def test_unrelated_host_not_accepted(self):
        routes = [{"match": [{"host": ["example.org"]}],
                   "handle": [{"handler": "reverse_proxy"}]}]
        self.assertEqual(visit_routes(routes), (False, False))

    def test_nested_dev_host_match(self):
        routes = [{"handle": [{"handler": "subroute", "routes": [
            {"match": [{"host": ["dev.vencira.es"]}],
             "handle": [{"handler": "reverse_proxy"}]}
        ]}]}]
        self.assertEqual(visit_routes(routes), (True, True))

    def test_unrelated_nested_host_not_leaked(self):
        routes = [{"match": [{"host": ["dev.vencira.es"]}],
                   "handle": [{"handler": "subroute", "routes": [
                       {"match": [{"host": ["example.org"]}],
                        "handle": [{"handler": "reverse_proxy"}]}
                   ]}]}]
        self.assertEqual(visit_routes(routes), (True, False))

    def test_dev_host_without_reverse_proxy_not_verified(self):
        routes = [{"match": [{"host": ["dev.vencira.es"]}],
                   "handle": [{"handler": "static_response"}]}]
        self.assertEqual(visit_routes(routes), (True, False))


if __name__ == "__main__":
    unittest.main()
