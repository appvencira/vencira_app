"""Explicit DRF bearer authentication candidate; never installed by defaults.

Production's SessionAuthentication and CSRF remain intact. This separate
authenticator must be explicitly selected by a future native-only view AFTER
authorization of G1/G2/G3 and the operational release.
"""
from django.conf import settings
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .session_store import MobileTokenDenied, validate_candidate_access


class CandidateMobileBearerAuthentication(BaseAuthentication):
    def authenticate(self, request):
        value = request.META.get("HTTP_AUTHORIZATION")
        if value is None:
            return None

        # Even correct credentials are useless until the server release gate
        # and route registration are explicitly approved.
        if not (
            settings.VENCIRA_ENV == "test"
            and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
            and settings.VENCIRA_NATIVE_BEARER_ENABLED
        ):
            raise AuthenticationFailed("Mobile authentication unavailable")
        if (
            not isinstance(value, str)
            or len(value) > 160
            or value.count(" ") != 1
            or not value.startswith("Bearer ")
            or request.META.get("HTTP_COOKIE")
            or request.META.get("HTTP_ORIGIN")
            or request.META.get("HTTP_REFERER")
            or not request.is_secure()
        ):
            raise AuthenticationFailed("Mobile authentication unavailable")

        try:
            user = validate_candidate_access(value[7:])
        except MobileTokenDenied as exc:
            raise AuthenticationFailed(
                "Mobile authentication unavailable"
            ) from exc
        return user, None

    def authenticate_header(self, request):
        return 'Bearer realm="VENCIRA mobile"'
