"""I8-I test-only PG17 negative policy: no-MFA and recovery never issue.

This is a DENIAL/ABSENCE gate, NOT implementation or authorization of
password-only login or full account-wide recovery.
"""
import json
import os
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, resolve

from reminders.models import UserMfaState
from .models import MobileDeviceSession, MobilePendingChallenge


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_i8d_urls",
    VENCIRA_G5_ABUSE_KEY="i8i-pg17-disposable-account-abuse-key-test-only",
    VENCIRA_G5_AUDIT_KEY="i8i-pg17-disposable-account-audit-key-test-only",
)
class I8INonMfaRecoveryDeniedPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("I8-I requires disposable PostgreSQL 17")
        scope = patch.dict(os.environ, {"VENCIRA_I8D_HTTP_LAB": "1"})
        scope.start()
        self.addCleanup(scope.stop)
        self.user = get_user_model().objects.create_user(
            username="i8i-password-only-synthetic",
            password="i8i-disposable-password",
        )

    def password(self, username=None, password="i8i-disposable-password"):
        return self.client.post(
            "/api/v1/mobile/auth/password/",
            data=json.dumps({
                "username": username or self.user.username,
                "password": password,
            }),
            content_type="application/json",
        )

    def assert_no_authority(self):
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(MobilePendingChallenge.objects.exists())

    def test_no_mfa_record_password_never_issues(self):
        response = self.password()
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json(), {"error": "native_auth_unavailable"})
        self.assertNotIn("Set-Cookie", response)
        self.assert_no_authority()

    def test_disabled_mfa_record_password_never_issues(self):
        UserMfaState.objects.create(
            user=self.user, enabled=False, session_epoch=1,
            encrypted_totp_secret="",
        )
        response = self.password()
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json(), {"error": "native_auth_unavailable"})
        self.assert_no_authority()

    def test_no_mfa_wrong_password_same_uniform_response(self):
        good = self.password()
        wrong = self.password(password="i8i-incorrect")
        self.assertEqual(good.status_code, 401)
        self.assertEqual(wrong.status_code, 401)
        self.assertEqual(good.json(), wrong.json())
        self.assert_no_authority()

    def test_no_mfa_user_with_unexpected_totp_cannot_issue(self):
        response = self.client.post(
            "/api/v1/mobile/auth/mfa/",
            data=json.dumps({"challenge": "not-a-challenge", "code": "000000"}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json(), {"error": "native_auth_unavailable"})
        self.assert_no_authority()

    def test_no_mfa_cannot_use_refresh_or_bearer(self):
        refresh = self.client.post(
            "/api/v1/mobile/token/refresh/",
            data=json.dumps({"refresh": "invalid"}),
            content_type="application/json",
        )
        me = self.client.get(
            "/api/v1/mobile/me/", HTTP_AUTHORIZATION="Bearer invalid",
        )
        self.assertEqual(refresh.status_code, 401)
        self.assertEqual(me.status_code, 401)
        self.assert_no_authority()

    def test_synthetic_recovery_endpoints_absent_from_lab_urlconf(self):
        for path in (
            "/api/v1/mobile/auth/recover/password/",
            "/api/v1/mobile/auth/recover/mfa/",
            "/api/v1/mobile/token/recover/",
        ):
            with self.subTest(path=path):
                with self.assertRaises(Resolver404):
                    resolve(path)
        self.assert_no_authority()

    def test_public_operational_urlconf_has_no_native_issuer_or_recovery(self):
        with override_settings(ROOT_URLCONF="config.urls"):
            for path in (
                "/api/v1/mobile/auth/password/",
                "/api/v1/mobile/auth/mfa/",
                "/api/v1/mobile/auth/recover/password/",
                "/api/v1/mobile/auth/recover/mfa/",
            ):
                with self.subTest(path=path):
                    with self.assertRaises(Resolver404):
                        resolve(path)
        self.assert_no_authority()

    def test_disabling_candidate_flag_refuses_auth_even_in_lab_urlconf(self):
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            response = self.password()
        self.assertEqual(response.status_code, 404)
        self.assert_no_authority()
