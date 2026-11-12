"""D27 isolated HTTP adapter integration checks; PostgreSQL 17 only."""
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
    ROOT_URLCONF="native_mobile_service.test_d27_http_urls",
    VENCIRA_D27_CORE_AUDIT_KEY="d27-http-synthetic-audit-key-2026",
    VENCIRA_D27_CORE_ABUSE_KEY="d27-http-synthetic-abuse-key-2026",
)
class D27LabHttpPG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires ephemeral PostgreSQL 17")
        key = Fernet.generate_key().decode("ascii")
        env = patch.dict(os.environ, {
            "VENCIRA_D27_HTTP_LAB": "1",
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        })
        env.start()
        self.addCleanup(env.stop)
        self.secret = generate_secret()
        self.user = get_user_model().objects.create_user(
            username="d27-http", password="d27-http-synthetic-password",
        )
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[key],
            ),
        )

    def post(self, route, value, **kwargs):
        return self.client.post(
            "/api/v1/mobile/" + route,
            data=json.dumps(value), content_type="application/json",
            secure=True, **kwargs,
        )

    def test_issue_rotate_revoke(self):
        first = self.post("auth/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(first.status_code, 200)
        self.assertTrue(first.json()["challenge"].startswith("oc1."))
        self.assertFalse(MobileDeviceSession.objects.exists())
        issued = self.post("auth/mfa/", {
            "challenge": first.json()["challenge"],
            "code": totp_at(self.secret, int(time.time())),
        })
        self.assertEqual(issued.status_code, 200)
        self.assertNotIn("Set-Cookie", issued)
        self.assertEqual(issued["Cache-Control"], "no-store, max-age=0")
        old = issued.json()
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + old["access"],
        ).status_code, 200)
        rotated = self.post("token/refresh/", {"refresh": old["refresh"]})
        self.assertEqual(rotated.status_code, 200)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + old["access"],
        ).status_code, 401)
        self.assertEqual(self.post(
            "token/revoke/", {"refresh": rotated.json()["refresh"]},
        ).status_code, 200)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + rotated.json()["access"],
        ).status_code, 401)
        print("D27_LAB_HTTP_ISSUE_ROTATE_REVOKE_PG17=PASS")

    def test_https_metadata_json_and_absent_public_route(self):
        payload = {"username": self.user.username,
                   "password": "d27-http-synthetic-password"}
        route = "/api/v1/mobile/auth/password/"
        self.assertEqual(self.client.post(
            route, data=json.dumps(payload), content_type="application/json",
            secure=False,
        ).status_code, 403)
        for headers in (
            {"HTTP_COOKIE": "sessionid=fake"},
            {"HTTP_ORIGIN": "https://untrusted.invalid"},
            {"HTTP_X_FORWARDED_FOR": "198.51.100.1"},
            {"HTTP_X_FORWARDED_PROTO": "https"},
            {"HTTP_AUTHORIZATION": "Bearer fake"},
        ):
            with self.subTest(headers=headers):
                self.assertEqual(self.post("auth/password/", payload, **headers).status_code, 403)
        duplicate = self.client.post(
            route, data='{"username":"a","username":"b","password":"c"}',
            content_type="application/json", secure=True,
        )
        self.assertEqual(duplicate.status_code, 400)
        self.assertFalse(MobileDeviceSession.objects.exists())
        with override_settings(ROOT_URLCONF="config.urls"):
            clear_url_caches()
            try:
                with self.assertRaises(Resolver404):
                    resolve(route)
            finally:
                clear_url_caches()
        with patch.dict(os.environ, {"VENCIRA_D27_HTTP_LAB": "0"}):
            self.assertEqual(self.post("auth/password/", payload).status_code, 404)
        print("D27_LAB_HTTP_TLS_AND_PUBLIC_ROUTE_FENCES_PG17=PASS")

    def test_recovery_http_revokes_old_account_sessions(self):
        initial = self.post("auth/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(initial.status_code, 200)
        old = self.post("auth/mfa/", {
            "challenge": initial.json()["challenge"],
            "code": totp_at(self.secret, int(time.time()) - 30),
        })
        self.assertEqual(old.status_code, 200)
        recovery = self.post("auth/recover/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(recovery.status_code, 200)
        self.assertTrue(recovery.json()["challenge"].startswith("or1."))
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        fresh = self.post("auth/recover/mfa/", {
            "challenge": recovery.json()["challenge"],
            "code": totp_at(self.secret, int(time.time())),
        })
        self.assertEqual(fresh.status_code, 200)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + old.json()["access"],
        ).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + fresh.json()["access"],
        ).status_code, 200)
        print("D27_LAB_HTTP_ACCOUNT_RECOVERY_PG17=PASS")

    def test_lost_issue_response_consumes_challenge_without_retry_issue(self):
        first = self.post("auth/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(first.status_code, 200)
        wire = first.json()["challenge"]
        payload = {"challenge": wire, "code": totp_at(self.secret, int(time.time()))}
        # Server committed the issue, but the client never receives its body.
        discarded = self.post("auth/mfa/", payload)
        self.assertEqual(discarded.status_code, 200)
        del discarded
        self.assertEqual(self.post("auth/mfa/", payload).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        print("D27_LAB_HTTP_LOST_ISSUE_RESPONSE_FAIL_CLOSED_PG17=PASS")

    def test_lost_refresh_response_replay_revokes_device(self):
        begin = self.post("auth/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(begin.status_code, 200)
        initial = self.post("auth/mfa/", {
            "challenge": begin.json()["challenge"],
            "code": totp_at(self.secret, int(time.time())),
        })
        self.assertEqual(initial.status_code, 200)
        original = initial.json()
        # First refresh succeeds, but the new pair is not delivered.
        discarded = self.post("token/refresh/", {"refresh": original["refresh"]})
        self.assertEqual(discarded.status_code, 200)
        del discarded
        # Retrying the spent token is a replay and must revoke the session.
        self.assertEqual(self.post(
            "token/refresh/", {"refresh": original["refresh"]},
        ).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertIsNotNone(MobileDeviceSession.objects.get().revoked_at)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + original["access"],
        ).status_code, 401)
        print("D27_LAB_HTTP_LOST_REFRESH_REPLAY_REVOKES_PG17=PASS")

    def test_lost_recovery_response_keeps_old_devices_revoked(self):
        first = self.post("auth/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(first.status_code, 200)
        initial = self.post("auth/mfa/", {
            "challenge": first.json()["challenge"],
            "code": totp_at(self.secret, int(time.time()) - 30),
        })
        self.assertEqual(initial.status_code, 200)
        old_access = initial.json()["access"]
        recovery = self.post("auth/recover/password/", {
            "username": self.user.username,
            "password": "d27-http-synthetic-password",
        })
        self.assertEqual(recovery.status_code, 200)
        wire = recovery.json()["challenge"]
        payload = {"challenge": wire, "code": totp_at(self.secret, int(time.time()))}
        # Successful account recovery commits even if HTTP response is lost.
        discarded = self.post("auth/recover/mfa/", payload)
        self.assertEqual(discarded.status_code, 200)
        del discarded
        self.assertEqual(self.post("auth/recover/mfa/", payload).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
            HTTP_AUTHORIZATION="Bearer " + old_access,
        ).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.count(), 2)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        print("D27_LAB_HTTP_LOST_RECOVERY_RESPONSE_OLD_REVOKED_PG17=PASS")
