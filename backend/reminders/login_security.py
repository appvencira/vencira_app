"""Protección provisional del login por identificador HMAC usando la BD compartida.

No es defensa definitiva: para producción añadir controles IP en el proxy,
MFA, recuperación de acceso, mantenimiento de registros y alertas de abuso.
"""
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.views import LoginView
from django.db import transaction
from django.http import HttpResponse
from django.utils import timezone
from django.utils.crypto import salted_hmac

from .models import LoginAttemptBucket

WINDOW = timedelta(minutes=15)
MAX_FAILURES = 5
BLOCK = timedelta(minutes=15)


def _key(username: str) -> str:
    # Hash con secreto del servidor; no persistir el nombre de cuenta.
    username = username.strip().casefold()[:150]
    return salted_hmac("vencira.login.bucket.v1", username, secret=settings.SECRET_KEY).hexdigest()


def is_blocked(username: str, *, now=None) -> bool:
    current = now or timezone.now()
    item = LoginAttemptBucket.objects.filter(pk=_key(username)).first()
    return bool(item and item.blocked_until and item.blocked_until > current)


def register_failure(username: str, *, now=None) -> None:
    current = now or timezone.now()
    key = _key(username)
    with transaction.atomic():
        LoginAttemptBucket.objects.get_or_create(
            key=key, defaults={"started_at": current},
        )
        item = LoginAttemptBucket.objects.select_for_update().get(pk=key)
        if item.blocked_until and item.blocked_until > current:
            return
        if current - item.started_at >= WINDOW:
            item.started_at = current
            item.failures = 0
            item.blocked_until = None
        item.failures += 1
        if item.failures >= MAX_FAILURES:
            item.blocked_until = current + BLOCK
        item.save(update_fields=["started_at", "failures", "blocked_until", "updated_at"])


def clear_failures(username: str) -> None:
    LoginAttemptBucket.objects.filter(pk=_key(username)).delete()


class ProtectedLoginView(LoginView):
    template_name = "registration/login.html"

    def dispatch(self, request, *args, **kwargs):
        if request.method == "POST" and is_blocked(request.POST.get("username", "")):
            response = HttpResponse("Demasiados intentos. Prueba más tarde.", status=429)
            response["Cache-Control"] = "no-store"
            response["Retry-After"] = str(int(BLOCK.total_seconds()))
            return response
        return super().dispatch(request, *args, **kwargs)

    def form_invalid(self, form):
        register_failure(self.request.POST.get("username", ""))
        return super().form_invalid(form)

    def form_valid(self, form):
        # El reset solo se produce tras autenticación correcta.
        clear_failures(self.request.POST.get("username", ""))
        return super().form_valid(form)
