"""I8-D disposable PG17 HTTP contract, no production routes or services."""
import json
import os
import uuid
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, resolve

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from .models import MobileDeviceSession


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_i8d_urls",
    VENCIRA_G5_ABUSE_KEY="i8d-disposable-abuse-key-only-for-ci-postgres17",
    VENCIRA_G5_AUDIT_KEY="i8d-disposable-audit-key-only-for-ci-postgres17",
)
class I8DNativeHttpPG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("I8-D only on disposable PostgreSQL17")
        self.lab = patch.dict(os.environ, {
            "VENCIRA_I8D_HTTP_LAB": "1",
        })
        self.lab.start()
        self.addCleanup(self.lab.stop)
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.k = patch.dict(os.environ, {"VENCIRA_I8D_MFA_KEY": self.keys[0]})
        self.k.start()
        self.addCleanup(self.k.stop)
        self.user = get_user_model().objects.create_user(
            username="i8d-synthetic", password="synthetic-i8d-password",
        )
        self.secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=3,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def post(self, path, value, **extra):
        return self.client.post(
            path, data=json.dumps(value), content_type="application/json", **extra,
        )

    def password(self):
        return self.post("/api/v1/mobile/auth/password/", {
            "username": self.user.username, "password": "synthetic-i8d-password",
        })

    def mfa(self, challenge, code=None):
        return self.post("/api/v1/mobile/auth/mfa/", {
            "challenge": challenge,
            "code": code if code is not None else totp_at(self.secret, int(__import__("time").time())),
        })

    def test_password_has_no_tokens_and_mfa_issues(self):
        response = self.password()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "mfa_required")
        self.assertEqual(set(response.json()), {"status", "challenge"})
        self.assertFalse(MobileDeviceSession.objects.exists())
        second = self.mfa(response.json()["challenge"])
        self.assertEqual(second.status_code, 200)
        self.assertEqual(set(second.json()), {"status", "access", "refresh"})
        self.assertEqual(second.json()["status"], "authenticated")
        self.assertNotIn("Set-Cookie", response)
        self.assertNotIn("Set-Cookie", second)
        self.assertEqual(second["Cache-Control"], "no-store, max-age=0")
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    def test_replay_rejected(self):
        challenge = self.password().json()["challenge"]
        self.assertEqual(self.mfa(challenge).status_code, 200)
        self.assertEqual(self.mfa(challenge).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    def test_wrong_password_uniform_and_no_session(self):
        r = self.post("/api/v1/mobile/auth/password/", {
            "username": "missing-i8d-user", "password": "wrong",
        })
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.json(), {"error": "native_auth_unavailable"})
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_totp_denied_and_session_not_created(self):
        challenge = self.password().json()["challenge"]
        correct = totp_at(self.secret, int(__import__("time").time()))
        wrong = "000000" if correct != "000000" else "111111"
        self.assertEqual(self.mfa(challenge, wrong).status_code, 401)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_refresh_replay_revokes(self):
        challenge = self.password().json()["challenge"]
        tokens = self.mfa(challenge).json()
        refresh = tokens["refresh"]
        rotated = self.post("/api/v1/mobile/token/refresh/", {"refresh": refresh})
        self.assertEqual(rotated.status_code, 200)
        next_tokens = rotated.json()
        self.assertNotEqual(next_tokens["refresh"], refresh)
        self.assertEqual(self.post("/api/v1/mobile/token/refresh/", {"refresh": refresh}).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", HTTP_AUTHORIZATION="Bearer " + next_tokens["access"],
        ).status_code, 401)

    def test_logout_revokes_bearer_me(self):
        challenge = self.password().json()["challenge"]
        tokens = self.mfa(challenge).json()
        authorized = self.client.get(
            "/api/v1/mobile/me/", HTTP_AUTHORIZATION="Bearer " + tokens["access"],
        )
        self.assertEqual(authorized.status_code, 200)
        self.assertEqual(self.post("/api/v1/mobile/token/revoke/", {
            "refresh": tokens["refresh"],
        }).json(), {"status": "revoked"})
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", HTTP_AUTHORIZATION="Bearer " + tokens["access"],
        ).status_code, 401)

    def test_cookie_origin_and_bearer_for_post_denied(self):
        fields = {"username": self.user.username, "password": "synthetic-i8d-password"}
        path = "/api/v1/mobile/auth/password/"
        self.assertEqual(self.post(path, fields, HTTP_COOKIE="vencira_sessionid=abc").status_code, 403)
        self.assertEqual(self.post(path, fields, HTTP_ORIGIN="https://untrusted.test").status_code, 403)
        self.assertEqual(self.post(path, fields, HTTP_AUTHORIZATION="Bearer anything").status_code, 403)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_invalid_body_and_method_denied(self):
        path = "/api/v1/mobile/auth/password/"
        self.assertEqual(self.client.get(path).status_code, 405)
        self.assertEqual(self.client.post(path, data="not-json", content_type="application/json").status_code, 400)
        self.assertEqual(self.post(path, {"username": "ok", "password": "ok", "extra": "bad"}).status_code, 400)
        self.assertEqual(self.post(path, {"username": "ok", "password": 2}).status_code, 400)
        self.assertEqual(self.client.post(path, data="x" * 5000, content_type="application/json").status_code, 400)

    def test_flag_off_denies_every_path(self):
        os.environ["VENCIRA_I8D_HTTP_LAB"] = "0"
        paths = [
            "/api/v1/mobile/auth/password/", "/api/v1/mobile/auth/mfa/",
            "/api/v1/mobile/token/refresh/", "/api/v1/mobile/token/revoke/",
        ]
        for p in paths:
            with self.subTest(path=p):
                self.assertEqual(self.post(p, {}).status_code, 404)
        self.assertEqual(self.client.get("/api/v1/mobile/me/").status_code, 404)

    def test_no_operational_routing_from_original_urlconf(self):
        with override_settings(ROOT_URLCONF="config.urls"):
            from django.urls import clear_url_caches
            clear_url_caches()
            for path in (
                "/api/v1/mobile/auth/password/", "/api/v1/mobile/auth/mfa/",
                "/api/v1/mobile/token/refresh/", "/api/v1/mobile/token/revoke/",
            ):
                with self.subTest(path=path), self.assertRaises(Resolver404):
                    resolve(path)
            clear_url_caches()
