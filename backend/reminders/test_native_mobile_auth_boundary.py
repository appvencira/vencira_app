"""N1: native mobile auth is NOT launched; guard the existing web boundary.

This suite intentionally does not create bearer credentials or mobile endpoints.
It detects accidental exposure until a separately reviewed N1 contract exists.
"""
from django.conf import settings
from django.test import SimpleTestCase
from django.urls import resolve

from reminders.login_security import ProtectedLoginView
from reminders.mfa_challenge import mfa_challenge
from reminders.mfa_middleware import RequireMfaSessionMiddleware


class MobileAuthBoundaryTests(SimpleTestCase):
    def test_rest_framework_defaults_remain_session_only(self):
        classes = settings.REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"]
        self.assertEqual(
            classes, ["rest_framework.authentication.SessionAuthentication"]
        )

    def test_session_auth_mfa_middleware_not_bypassed(self):
        middleware = settings.MIDDLEWARE
        self.assertIn("django.contrib.sessions.middleware.SessionMiddleware", middleware)
        self.assertIn("django.middleware.csrf.CsrfViewMiddleware", middleware)
        self.assertIn("django.contrib.auth.middleware.AuthenticationMiddleware", middleware)
        self.assertIn("reminders.mfa_middleware.RequireMfaSessionMiddleware", middleware)
        self.assertLess(
            middleware.index("django.contrib.auth.middleware.AuthenticationMiddleware"),
            middleware.index("reminders.mfa_middleware.RequireMfaSessionMiddleware"),
        )
        self.assertTrue(callable(RequireMfaSessionMiddleware))

    def test_web_login_and_mfa_still_use_reviewed_handlers(self):
        self.assertIs(resolve("/accounts/login/").func.view_class, ProtectedLoginView)
        self.assertIs(resolve("/accounts/mfa/").func, mfa_challenge)

    def test_unapproved_mobile_auth_paths_do_not_exist(self):
        from django.urls import Resolver404
        for path in (
            "/api/v1/mobile/auth/",
            "/api/v1/mobile/token/",
            "/api/v1/mobile/token/refresh/",
            "/api/v1/mobile/token/revoke/",
            "/api/v1/mobile/auth/password/",
            "/api/v1/mobile/auth/mfa/",
            "/api/v1/mobile/auth/recover/password/",
            "/api/v1/mobile/auth/recover/mfa/",
            "/api/v1/mobile/me/",
        ):
            with self.subTest(path=path), self.assertRaises(Resolver404):
                resolve(path)

    def test_no_secret_cookies_relaxations_for_mobile(self):
        self.assertTrue(settings.SESSION_COOKIE_HTTPONLY)
        self.assertEqual(settings.SESSION_COOKIE_SAMESITE, "Lax")
        self.assertEqual(settings.CSRF_COOKIE_SAMESITE, "Lax")

    def test_device_session_lab_is_absent_from_normal_django(self):
        self.assertFalse(getattr(settings, "VENCIRA_NATIVE_SESSION_LAB", False))
        self.assertNotIn("native_sessions_lab", settings.INSTALLED_APPS)

    def test_bearer_header_cannot_authenticate_web_session_api(self):
        # The mobile gateway is disabled; never silently treat arbitrary
        # bearer data as an authenticated Django user.
        response = self.client.get(
            "/api/v1/me/",
            HTTP_AUTHORIZATION="Bearer synthetic-invalid-test-only",
        )
        self.assertIn(response.status_code, (401, 403))
