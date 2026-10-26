"""D1.5f: reto MFA previo a la autenticación. Sin enrolamiento público."""
import os
from datetime import timedelta

from django.contrib.auth import get_user_model, login as auth_login
from django.http import HttpResponse
from django.shortcuts import redirect
from django.utils import timezone
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_http_methods

from .mfa_store import consume_recovery_code, consume_totp
from .models import UserMfaState

PENDING_KEY = "vencira_mfa_pending_v1"
CHALLENGE_SECONDS = 300


def _mfa_keys():
    raw = os.getenv("VENCIRA_MFA_FERNET_KEYS", "")
    keys = [item.strip() for item in raw.split(",") if item.strip()]
    # No fallback to Django SECRET_KEY. Misconfiguration fails closed.
    return keys


@never_cache
@csrf_protect
@require_http_methods(["GET", "POST"])
def mfa_challenge(request):
    pending = request.session.get(PENDING_KEY)
    if not isinstance(pending, dict):
        return redirect("login")
    issued = pending.get("issued")
    uid = pending.get("user_id")
    backend = pending.get("backend")
    if (not isinstance(issued, int) or
        timezone.now().timestamp() - issued > CHALLENGE_SECONDS or
        timezone.now().timestamp() < issued or
        not isinstance(uid, int) or not isinstance(backend, str)):
        request.session.flush()
        return redirect("login")
    user = get_user_model().objects.filter(pk=uid, is_active=True).first()
    if user is None or not UserMfaState.objects.filter(user=user, enabled=True).exists():
        request.session.flush()
        return redirect("login")
    if request.method == "GET":
        return HttpResponse(
            '<!doctype html><html lang="es"><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>VENCIRA · Verificación</title><body>'
            '<h1>Segundo factor</h1><p>Introduce el código de tu autenticador '
            'o un código de recuperación.</p><form method="post">'
            '<input name="csrfmiddlewaretoken" type="hidden" value="' +
            __import__("django.middleware.csrf", fromlist=["get_token"]).get_token(request) +
            '"><input name="code" autocomplete="one-time-code" required '
            'aria-label="Código" maxlength="32">'
            '<button type="submit">Verificar</button></form></body></html>',
            content_type="text/html; charset=utf-8",
        )
    code = request.POST.get("code", "")
    keys = _mfa_keys()
    accepted = False
    if len(code) == 6 and keys:
        accepted = consume_totp(user.pk, code, keys=keys)
    elif len(code) == 32:
        accepted = consume_recovery_code(user.pk, code)
    if not accepted:
        response = HttpResponse("Código incorrecto o temporalmente bloqueado.", status=403)
        response["Cache-Control"] = "no-store"
        return response
    # La sesión estaba no autenticada; Django rota la clave al autenticar.
    next_url = pending.get("next", "/api/v1/me/")
    request.session.pop(PENDING_KEY, None)
    auth_login(request, user, backend=backend)
    response = redirect(next_url)
    response["Cache-Control"] = "no-store"
    return response
