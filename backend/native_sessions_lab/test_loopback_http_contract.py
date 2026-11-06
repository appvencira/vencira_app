"""G7-C: real TCP loopback HTTP for the *test-only* Django native issuer.

Uses Django LiveServerTestCase and the disposable Django test database.
The server binds 127.0.0.1 on an ephemeral port, never a public interface.
The URLconf is overridden only during this test case. This is NOT HTTPS,
Flutter-to-Django end-to-end, production routing, or a deployable server.
"""
import http.client
import json
from urllib.parse import urlsplit

from django.contrib.auth import get_user_model
from django.test import LiveServerTestCase, override_settings


_PASSWORD = "G7-C-Only-Synthetic-Lab-Password-2026!"
_PASSWORD_PATH = "/api/v1/mobile/auth/password/"
_ME_PATH = "/api/v1/mobile/me/"
_REVOKE_PATH = "/api/v1/mobile/token/revoke/"
_REFRESH_PATH = "/api/v1/mobile/token/refresh/"


@override_settings(ROOT_URLCONF="native_sessions_lab.test_urls")
class NativeLoopbackHttpContractTests(LiveServerTestCase):
    """HTTP socket contract only; run with VENCIRA_ENV=test and lab enabled."""

    host = "127.0.0.1"

    def setUp(self):
        super().setUp()
        self.user = get_user_model().objects.create_user(
            username="g7-c-socket-synthetic", password=_PASSWORD,
        )

    def _exchange(self, method, path, data=None, extra_headers=None):
        """Make a local-only request without proxies, cookies or redirects."""
        self.assertTrue(path.startswith("/api/v1/mobile/"))
        url = urlsplit(self.live_server_url)
        self.assertEqual(url.hostname, "127.0.0.1")
        self.assertEqual(url.scheme, "http")
        self.assertIsNotNone(url.port)

        payload = None if data is None else json.dumps(data).encode("utf-8")
        headers = {"Accept": "application/json"}
        if payload is not None:
            headers["Content-Type"] = "application/json"
        headers.update(extra_headers or {})

        connection = http.client.HTTPConnection(
            "127.0.0.1", url.port, timeout=5,
        )
        try:
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            status = response.status
            response_headers = {
                key.lower(): value for key, value in response.getheaders()
            }
            raw = response.read(16385)
            self.assertLessEqual(len(raw), 16384, "Oversized lab response")
            self.assertIn(
                "application/json", response_headers.get("content-type", ""),
            )
            return status, response_headers, json.loads(raw.decode("utf-8"))
        finally:
            connection.close()

    def _password(self):
        return self._exchange("POST", _PASSWORD_PATH, {
            "username": self.user.username,
            "password": _PASSWORD,
        })

    def test_socket_login_bearer_and_server_revocation(self):
        status, headers, granted = self._password()
        self.assertEqual(status, 200)
        self.assertEqual(granted.get("status"), "authenticated")
        self.assertTrue(granted["access"].startswith("v1.a."))
        self.assertTrue(granted["refresh"].startswith("v1.r."))
        self.assertNotIn("set-cookie", headers)
        self.assertIn("no-store", headers.get("cache-control", ""))

        status, _, me = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + granted["access"]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(me, {
            "authenticated": True, "user_id": self.user.pk,
        })
        status, _, denied = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + granted["refresh"]},
        )
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

        status, _, response = self._exchange(
            "POST", _REVOKE_PATH, {"refresh": granted["refresh"]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(response, {"status": "revoked"})
        status, _, denied = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + granted["access"]},
        )
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

    def test_socket_refresh_rotates_and_invalidates_previous_access(self):
        status, _, granted = self._password()
        self.assertEqual(status, 200)

        status, headers, rotated = self._exchange(
            "POST", _REFRESH_PATH, {"refresh": granted["refresh"]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(rotated.get("status"), "authenticated")
        self.assertTrue(rotated["access"].startswith("v1.a."))
        self.assertTrue(rotated["refresh"].startswith("v1.r."))
        self.assertTrue(
            rotated["access"] != granted["access"],
            "Access must rotate",
        )
        self.assertTrue(
            rotated["refresh"] != granted["refresh"],
            "Refresh must rotate",
        )
        self.assertNotIn("set-cookie", headers)

        status, _, _ = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + granted["access"]},
        )
        self.assertEqual(status, 401)
        status, _, _ = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + rotated["access"]},
        )
        self.assertEqual(status, 200)

        status, _, denied = self._exchange(
            "POST", _REFRESH_PATH, {"refresh": granted["refresh"]},
        )
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})
        status, _, _ = self._exchange(
            "GET", _ME_PATH,
            extra_headers={"Authorization": "Bearer " + rotated["access"]},
        )
        self.assertEqual(status, 401)

    def test_socket_browser_state_and_invalid_password_fail_closed(self):
        status, _, denied = self._exchange("POST", _PASSWORD_PATH, {
            "username": self.user.username,
            "password": "synthetic-incorrect",
        })
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

        data = {"username": self.user.username, "password": _PASSWORD}
        status, _, denied = self._exchange(
            "POST", _PASSWORD_PATH, data,
            extra_headers={"Cookie": "vencira_sessionid=synthetic-only"},
        )
        self.assertEqual(status, 403)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

        status, _, denied = self._exchange(
            "POST", _PASSWORD_PATH, data,
            extra_headers={"Origin": "https://example.invalid"},
        )
        self.assertEqual(status, 403)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

        status, _, denied = self._exchange("GET", _ME_PATH)
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})
