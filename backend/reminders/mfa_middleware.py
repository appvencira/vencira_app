"""Protección de sesión frente a vías de login alternativas (incluye /admin/)."""
from django.contrib.auth import logout
from django.http import HttpResponseForbidden

from .models import UserMfaState, MfaAdministrativeRecoveryCase

SESSION_VERIFIED = "vencira_mfa_verified_v1"
SESSION_EPOCH = "vencira_mfa_session_epoch_v1"


class RequireMfaSessionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        state = (UserMfaState.objects.filter(user_id=request.user.pk).first()
                 if request.user.is_authenticated else None)
        # Un expediente histórico no debe habilitar una cuenta con MFA desactivado.
        # Las transiciones administrativas nunca constituyen autorización de
        # acceso solo con contraseña; la reactivación MFA requiere su propio gate.
        cases = (MfaAdministrativeRecoveryCase.objects.filter(subject_id=request.user.pk)
                 if request.user.is_authenticated else MfaAdministrativeRecoveryCase.objects.none())
        recovery_block = (request.user.is_authenticated and (
            cases.filter(status=MfaAdministrativeRecoveryCase.Status.PENDING).exists()
            or (state is not None and not state.enabled and cases.exists())
        ))
        if recovery_block:
            logout(request)
            response = HttpResponseForbidden("Cuenta protegida durante recuperación MFA.")
            response["Cache-Control"] = "no-store"
            return response
        if (state is not None and state.enabled and (
                request.session.get(SESSION_VERIFIED) != request.user.get_session_auth_hash()
                or request.session.get(SESSION_EPOCH) != state.session_epoch)) :
            logout(request)
            response = HttpResponseForbidden("Se requiere verificación multifactor.")
            response["Cache-Control"] = "no-store"
            return response
        return self.get_response(request)
