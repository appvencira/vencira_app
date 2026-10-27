"""D1.5k: endpoints de enrolamiento custodiados tras feature flag APAGADO.

No habilitar sin custodia de claves, pruebas y procedimiento de recuperación.
"""
from django.conf import settings
from django.contrib.auth import authenticate
from django.http import HttpResponse
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .mfa_enrollment import confirm_mfa, prepare_mfa
from .mfa_key_config import load_mfa_keys
from .mfa_middleware import SESSION_VERIFIED
from .models import UserMfaState

PENDING_SETUP = "vencira_mfa_setup_v1"
SETUP_SECONDS = 600


def _response(data, code):
    response = Response(data, status=code)
    response["Cache-Control"] = "no-store"
    return response


def _keys():
    try:
        return load_mfa_keys()
    except ValueError:
        return None


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mfa_setup_start(request):
    if not getattr(settings, "VENCIRA_MFA_ENROLLMENT_ENABLED", False):
        return _response({"detail": "Función no disponible."}, 404)
    keys = _keys()
    if keys is None:
        return _response({"detail": "Configuración MFA no disponible."}, 503)
    if set(request.data) != {"password"} or not isinstance(request.data.get("password"), str):
        return _response({"detail": "Contraseña obligatoria."}, 400)
    password = request.data["password"]
    if not password or len(password) > 1024 or authenticate(
        request._request, username=request.user.get_username(), password=password,
    ) is None:
        return _response({"detail": "Confirmación incorrecta."}, 403)
    if UserMfaState.objects.filter(user=request.user, enabled=True).exists():
        return _response({"detail": "MFA ya está activo."}, 409)
    secret, uri = prepare_mfa(request.user, keys=keys)
    request.session[PENDING_SETUP] = {
        "uid": request.user.pk, "issued": int(timezone.now().timestamp()),
    }
    return _response({"secret": secret, "provisioning_uri": uri, "expires_in": SETUP_SECONDS}, 200)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mfa_setup_confirm(request):
    if not getattr(settings, "VENCIRA_MFA_ENROLLMENT_ENABLED", False):
        return _response({"detail": "Función no disponible."}, 404)
    pending = request.session.get(PENDING_SETUP)
    now = int(timezone.now().timestamp())
    if (not isinstance(pending, dict)
            or pending.get("uid") != request.user.pk
            or not isinstance(pending.get("issued"), int)
            or not 0 <= now - pending["issued"] <= SETUP_SECONDS):
        request.session.pop(PENDING_SETUP, None)
        return _response({"detail": "Preparación caducada. Reinicia el proceso."}, 409)
    if set(request.data) != {"code"} or not isinstance(request.data.get("code"), str):
        return _response({"detail": "Código TOTP obligatorio."}, 400)
    keys = _keys()
    if keys is None:
        return _response({"detail": "Configuración MFA no disponible."}, 503)
    codes = confirm_mfa(request.user.pk, request.data["code"], keys=keys)
    if codes is None:
        return _response({"detail": "Código incorrecto o preparación caducada."}, 403)
    request.session.pop(PENDING_SETUP, None)
    # Cuenta protegida desde este instante: sesión vigente queda verificada
    # por un TOTP recién validado; sesiones antiguas sin marcador se revocan.
    request.session[SESSION_VERIFIED] = request.user.get_session_auth_hash()
    return _response({
        "recovery_codes": codes,
        "warning": "Guarda los códigos ahora: no podrán volver a consultarse.",
    }, 200)
