"""Protección de sesión frente a vías de login alternativas (incluye /admin/)."""
from django.contrib.auth import logout
from django.http import HttpResponseForbidden

from .models import UserMfaState

SESSION_VERIFIED = "vencira_mfa_verified_v1"


class RequireMfaSessionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if (request.user.is_authenticated
                and UserMfaState.objects.filter(user_id=request.user.pk, enabled=True).exists()
                and request.session.get(SESSION_VERIFIED) != request.user.get_session_auth_hash()):
            logout(request)
            response = HttpResponseForbidden("Se requiere verificación multifactor.")
            response["Cache-Control"] = "no-store"
            return response
        return self.get_response(request)
