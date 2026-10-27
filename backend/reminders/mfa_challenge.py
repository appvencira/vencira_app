"""D1.5f: reto MFA previo a la autenticación. Sin enrolamiento público."""

from django.contrib.auth import get_user_model, login as auth_login
from django.utils.http import url_has_allowed_host_and_scheme
from django.http import HttpResponse
from django.shortcuts import redirect, render
from django.utils import timezone
from django.views.decorators.cache import never_cache
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_http_methods

from .mfa_store import consume_recovery_code, consume_totp
from .mfa_key_config import load_mfa_keys
from .mfa_middleware import SESSION_VERIFIED, SESSION_EPOCH
from .login_security import clear_failures
from .models import UserMfaState

PENDING_KEY = "vencira_mfa_pending_v1"
CHALLENGE_SECONDS = 300


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
        lang = "ca" if request.GET.get("lang") == "ca" else "es"
        response = render(request, "registration/mfa_challenge.html", {"lang": lang})
        response["Cache-Control"] = "no-store"
        return response
    code = request.POST.get("code", "")
    try:
        keys = load_mfa_keys()
    except ValueError:
        response = HttpResponse("MFA no disponible.", status=503)
        response["Cache-Control"] = "no-store"
        return response
    accepted = False
    if len(code) == 6:
        accepted = consume_totp(user.pk, code, keys=keys)
    elif len(code) == 32:
        accepted = consume_recovery_code(user.pk, code)
    if not accepted:
        response = HttpResponse("Código incorrecto o temporalmente bloqueado.", status=403)
        response["Cache-Control"] = "no-store"
        return response
    # La sesión estaba no autenticada; Django rota la clave al autenticar.
    next_url = pending.get("next", "/api/v1/me/")
    if not isinstance(next_url, str) or not url_has_allowed_host_and_scheme(
        next_url,
        allowed_hosts={request.get_host()},
        require_https=request.is_secure(),
    ):
        next_url = "/api/v1/me/"
    request.session.pop(PENDING_KEY, None)
    auth_login(request, user, backend=backend)
    request.session[SESSION_VERIFIED] = user.get_session_auth_hash()
    request.session[SESSION_EPOCH] = UserMfaState.objects.get(user=user).session_epoch
    clear_failures(user.get_username())
    response = redirect(next_url)
    response["Cache-Control"] = "no-store"
    return response
