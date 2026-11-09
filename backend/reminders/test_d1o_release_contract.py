"""D1-O: fail-closed HTTP/public route contract; synthetic DB only."""
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import Resolver404, resolve


class D1OReleaseContractTests(TestCase):
    def test_native_candidate_not_in_public_urlconf(self):
        self.assertFalse(settings.VENCIRA_NATIVE_BEARER_ENABLED)
        self.assertNotIn("native_mobile_service", settings.INSTALLED_APPS)
        self.assertNotIn("native_sessions_lab", settings.INSTALLED_APPS)
        self.assertNotIn("renewal_attachments", settings.INSTALLED_APPS)
        for path in (
            "/api/native/sessions/",
            "/api/v1/native/issue/",
            "/api/v1/native/refresh/",
            "/api/v1/native/recovery/",
        ):
            with self.subTest(path=path):
                with self.assertRaises(Resolver404):
                    resolve(path)

    def test_anonymous_access_to_protected_workspace_api_denied(self):
        for path in (
            "/api/v1/me/",
            "/api/v1/workspaces/",
        ):
            with self.subTest(path=path):
                response = self.client.get(path)
                self.assertIn(response.status_code, (401, 403))

    def test_login_post_requires_csrf_token(self):
        client = Client(enforce_csrf_checks=True)
        response = client.post(
            "/accounts/login/",
            {"username": "d1o-unknown", "password": "invalid"},
        )
        self.assertEqual(response.status_code, 403)

    def test_mfa_enrollment_disabled_for_authenticated_user(self):
        self.assertFalse(settings.VENCIRA_MFA_ENROLLMENT_ENABLED)
        user = get_user_model().objects.create_user(
            username="d1o-fixture", password="Synthetic-Only-42!"
        )
        self.client.force_login(user)
        response = self.client.post(
            "/api/v1/me/mfa/setup/start/",
            data="{}",
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 404)

    def test_session_auth_only_no_bearer(self):
        auth_classes = settings.REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"]
        self.assertEqual(auth_classes, ["rest_framework.authentication.SessionAuthentication"])
