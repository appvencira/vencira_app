"""Static auth-surface safety assertions. No MFA enablement or live access."""
from django.conf import settings
from django.test import SimpleTestCase
from django.urls import get_resolver


class MfaAuthenticationSurfaceTests(SimpleTestCase):
    def test_mfa_middleware_precedes_application_processing(self):
        middleware = list(settings.MIDDLEWARE)
        self.assertIn("reminders.mfa_middleware.RequireMfaSessionMiddleware", middleware)
        self.assertGreater(
            middleware.index("reminders.mfa_middleware.RequireMfaSessionMiddleware"),
            middleware.index("django.contrib.auth.middleware.AuthenticationMiddleware"),
        )

    def test_rest_api_has_no_token_auth_bypass(self):
        classes = settings.REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"]
        self.assertEqual(classes, ["rest_framework.authentication.SessionAuthentication"])

    def test_no_public_administrative_recovery_endpoint(self):
        def walk(patterns, prefix=""):
            for item in patterns:
                route = prefix + str(item.pattern)
                if hasattr(item, "url_patterns"):
                    yield from walk(item.url_patterns, route)
                else:
                    yield route
        routes = tuple(walk(get_resolver().url_patterns))
        self.assertFalse(any(
            "mfa" in route and any(
                item in route for item in ("admin-recovery", "factor-reset", "lost-factor")
            )
            for route in routes
        ))
