"""D22 integrated HTTP contract backed by server-owned MFA keys in PG17."""
import json
import os
import time
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, clear_url_caches, resolve

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from .models import MobileDeviceSession


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_d22_urls",
    VENCIRA_G5_ABUSE_KEY="d22-ephemeral-abuse-pg17-key-only",
    VENCIRA_G5_AUDIT_KEY="d22-ephemeral-audit-pg17-key-only",
)
class D22NativeServerCustodyHttpPG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D22 requires isolated PG17")
        self.key = Fernet.generate_key().decode("ascii")
        self.environment = patch.dict(os.environ, {
            "VENCIRA_D22_HTTP_LAB": "1",
            "VENCIRA_MFA_FERNET_KEYS": self.key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
            "VENCIRA_I8D_MFA_KEY": "not-a-real-key",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.secret = generate_secret()
        self.user = get_user_model().objects.create_user(
            username="d22-http-synthetic", password="d22-only-password",
        )
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=3,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[self.key],
            ),
        )

    def post(self, path, payload, **kwargs):
        return self.client.post(
            path, data=json.dumps(payload), content_type="application/json",
            secure=True, **kwargs,
        )

    def password(self, *, recovery=False):
        path = "/api/v1/mobile/auth/recover/password/" if recovery else "/api/v1/mobile/auth/password/"
        return self.post(path, {
            "username": self.user.username, "password": "d22-only-password",
        })

    def finish(self, challenge, *, recovery=False, at=None):
        path = "/api/v1/mobile/auth/recover/mfa/" if recovery else "/api/v1/mobile/auth/mfa/"
        return self.post(path, {
            "challenge": challenge,
            "code": totp_at(self.secret, int(time.time()) if at is None else at),
        })

    def test_issuance_uses_server_key_and_http_json_contract(self):
        response = self.password()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.json()), {"status", "challenge"})
        self.assertFalse(MobileDeviceSession.objects.exists())
        tokens = self.finish(response.json()["challenge"])
        self.assertEqual(tokens.status_code, 200)
        self.assertEqual(set(tokens.json()), {"status", "access", "refresh"})
        self.assertNotIn("Set-Cookie", tokens)
        self.assertEqual(tokens["Cache-Control"], "no-store, max-age=0")
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + tokens.json()["access"],
        ).status_code, 200)
        print("D22_SERVER_CUSTODIED_HTTP_ISSUANCE=PASS")

    def test_account_recovery_revokes_prior_access_only_after_fresh_mfa(self):
        initial_challenge = self.password().json()["challenge"]
        first = self.finish(initial_challenge)
        self.assertEqual(first.status_code, 200)
        old = first.json()["access"]
        response = self.password(recovery=True)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        later = int(time.time()) + 120
        with patch("reminders.mfa_totp.time.time", return_value=later):
            new = self.finish(response.json()["challenge"], recovery=True,
                              at=later)
        self.assertEqual(new.status_code, 200)
        self.assertNotEqual(old, new.json()["access"])
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + old,
        ).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + new.json()["access"],
        ).status_code, 200)
        self.assertEqual(self.post(
            "/api/v1/mobile/token/revoke/",
            {"refresh": new.json()["refresh"]},
        ).status_code, 200)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + new.json()["access"],
        ).status_code, 401)
        print("D22_HTTP_RECOVERY_ATOMIC_REVOKE=PASS")

    def test_tls_cookie_origin_referer_and_auth_header_fences(self):
        path = "/api/v1/mobile/auth/password/"
        payload = {"username": self.user.username, "password": "d22-only-password"}
        self.assertEqual(self.client.post(
            path, data=json.dumps(payload), content_type="application/json",
            secure=False,
        ).status_code, 403)
        for extras in (
            {"HTTP_COOKIE": "sessionid=fake"},
            {"HTTP_ORIGIN": "https://untrusted.invalid"},
            {"HTTP_REFERER": "https://untrusted.invalid"},
            {"HTTP_AUTHORIZATION": "Bearer fake"},
        ):
            with self.subTest(extras=extras):
                self.assertEqual(self.post(path, payload, **extras).status_code, 403)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        print("D22_HTTP_CLIENT_METADATA_FENCED=PASS")

    def test_missing_server_key_and_malformed_json_fail_closed(self):
        challenge = self.password().json()["challenge"]
        with patch.dict(os.environ, {"VENCIRA_MFA_FERNET_KEYS": "invalid"}):
            self.assertEqual(self.finish(challenge).status_code, 401)
        self.assertFalse(MobileDeviceSession.objects.exists())
        path = "/api/v1/mobile/auth/password/"
        response = self.client.post(
            path,
            data='{"username":"x","username":"y","password":"z"}',
            content_type="application/json", secure=True,
        )
        self.assertEqual(response.status_code, 400)
        self.assertNotIn("Set-Cookie", response)
        print("D22_KEY_FAILURE_AND_DUPLICATE_JSON_DENIED=PASS")

    def test_routes_are_absent_from_config_and_flag_off_returns_404(self):
        with override_settings(ROOT_URLCONF="config.urls"):
            clear_url_caches()
            try:
                for route in (
                    "/api/v1/mobile/auth/password/",
                    "/api/v1/mobile/auth/mfa/",
                    "/api/v1/mobile/auth/recover/password/",
                    "/api/v1/mobile/auth/recover/mfa/",
                ):
                    with self.subTest(route=route), self.assertRaises(Resolver404):
                        resolve(route)
            finally:
                clear_url_caches()
        os.environ["VENCIRA_D22_HTTP_LAB"] = "0"
        self.assertEqual(self.password().status_code, 404)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
        ).status_code, 404)
        print("D22_OPERATIONAL_ROUTES_ABSENT=PASS")
