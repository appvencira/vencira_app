"""I7-A: native token issuer remains unavailable, even with candidate app enabled.

Tests run only against disposable Django databases. No token can be issued.
"""
from django.conf import settings
from django.test import SimpleTestCase
from django.urls import Resolver404, resolve

from .g14_issuance_contract import (
    IssuanceSecurityEvidence,
    missing_issuance_requirements,
)
from .g14_locked_verifier import verify_candidate_password_only


UNAUTHORIZED_NATIVE_ROUTES = (
    "/api/v1/mobile/auth/",
    "/api/v1/mobile/token/",
    "/api/v1/mobile/token/refresh/",
    "/api/v1/mobile/token/revoke/",
    "/api/v1/mobile/auth/password/",
    "/api/v1/mobile/auth/mfa/",
    "/api/v1/mobile/auth/challenge/",
    "/api/v1/mobile/auth/refresh/",
    "/api/v1/mobile/auth/revoke/",
    "/api/v1/mobile/me/",
    "/api/v1/native/login/",
    "/api/v1/native/token/",
)


class I7NativeIssuanceSeparationTests(SimpleTestCase):
    def test_candidate_is_never_registered_outside_explicit_lab(self):
        self.assertEqual(settings.VENCIRA_ENV, "test")
        self.assertTrue(settings.VENCIRA_NATIVE_SERVICE_CANDIDATE)
        self.assertIn("native_mobile_service", settings.INSTALLED_APPS)
        self.assertFalse(settings.VENCIRA_NATIVE_BEARER_ENABLED)

    def test_no_issuer_refresh_revoke_or_bearer_routes_even_with_candidate(self):
        for path in UNAUTHORIZED_NATIVE_ROUTES:
            with self.subTest(path=path), self.assertRaises(Resolver404):
                resolve(path)

    def test_framework_remains_cookie_session_only_even_with_candidate(self):
        self.assertEqual(
            settings.REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"],
            ["rest_framework.authentication.SessionAuthentication"],
        )

    def test_candidate_verifier_is_not_an_issuer(self):
        self.assertTrue(callable(verify_candidate_password_only))
        # No caller-supplied evidence can become a valid token: the policy
        # returns only names of missing conditions, never a signed credential.
        evidence = IssuanceSecurityEvidence(
            account_active=True,
            credential_version_current=True,
            generation_current=True,
            mfa_required=True,
            mfa_verified=True,
            mfa_epoch_current=True,
            recovery_quarantine_clear=True,
            abuse_budget_allowed=True,
            audit_ready=True,
        )
        result = missing_issuance_requirements(evidence)
        self.assertEqual(result, ())
        self.assertIsInstance(result, tuple)
        self.assertFalse(hasattr(result, "access"))
        self.assertFalse(hasattr(result, "refresh"))

    def test_bearer_header_never_authenticates_web_me_in_candidate_mode(self):
        response = self.client.get(
            "/api/v1/me/",
            HTTP_AUTHORIZATION="Bearer synthetic-i7a-not-an-issued-token",
        )
        self.assertIn(response.status_code, (401, 403))
