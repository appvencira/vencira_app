"""D27 lab-only HTTP adapter. Never registered in config.urls.

This does not authorize production transport or trust forwarded client IPs.
It relies on the independent D27 core, not candidate issuers.
"""
import os

from django.conf import settings
from django.views.decorators.csrf import csrf_exempt

from .native_http_contract import (
    native_auth_denied, native_json_response, parse_native_json,
)
from .native_operational_issuer_core import (
    OperationalCoreDenied, begin_verified_password, complete_verified_mfa,
    begin_recovery_password, complete_recovery_mfa,
    validate_verified_access, rotate_verified_refresh, revoke_verified_device,
)


def _guard(request, method):
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and settings.VENCIRA_NATIVE_BEARER_ENABLED is False
        and "native_mobile_service" in settings.INSTALLED_APPS
        and settings.ROOT_URLCONF == "native_mobile_service.test_d27_http_urls"
        and os.environ.get("VENCIRA_D27_HTTP_LAB") == "1"
    ):
        return native_auth_denied(status=404)
    if request.method != method:
        return native_auth_denied(status=405)
    # Only direct HTTPS requests in a lab. Do not accept spoofable proxy metadata.
    if (not request.is_secure() or request.META.get("HTTP_COOKIE")
            or request.META.get("HTTP_ORIGIN")
            or request.META.get("HTTP_REFERER")
            or request.META.get("HTTP_X_FORWARDED_FOR")
            or request.META.get("HTTP_FORWARDED")
            or request.META.get("HTTP_X_FORWARDED_PROTO")
            or request.META.get("HTTP_X_REAL_IP")
            or request.META.get("QUERY_STRING")):
        return native_auth_denied(status=403)
    if method == "POST" and request.META.get("HTTP_AUTHORIZATION"):
        return native_auth_denied(status=403)
    return None


def _deny():
    return native_auth_denied(status=401)


def _start(request, func):
    values = parse_native_json(request, ("username", "password"))
    if values is None:
        return native_auth_denied(status=400)
    try:
        challenge = func(username=values["username"],
                         password=values["password"],
                         remote_addr=request.META.get("REMOTE_ADDR"))
    except OperationalCoreDenied:
        return _deny()
    if not challenge:
        return _deny()
    return native_json_response({"status": "mfa_required", "challenge": challenge})


def _complete(request, func):
    values = parse_native_json(request, ("challenge", "code"))
    if values is None:
        return native_auth_denied(status=400)
    try:
        pair = func(challenge=values["challenge"], code=values["code"])
    except OperationalCoreDenied:
        return _deny()
    if not pair:
        return _deny()
    return native_json_response({
        "status": "authenticated", "access": pair[0], "refresh": pair[1],
    })


@csrf_exempt
def password(request):
    blocked = _guard(request, "POST")
    return blocked if blocked is not None else _start(request, begin_verified_password)


@csrf_exempt
def mfa(request):
    blocked = _guard(request, "POST")
    return blocked if blocked is not None else _complete(request, complete_verified_mfa)


@csrf_exempt
def recover_password(request):
    blocked = _guard(request, "POST")
    return blocked if blocked is not None else _start(request, begin_recovery_password)


@csrf_exempt
def recover_mfa(request):
    blocked = _guard(request, "POST")
    return blocked if blocked is not None else _complete(request, complete_recovery_mfa)


@csrf_exempt
def refresh(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    values = parse_native_json(request, ("refresh",))
    if values is None:
        return native_auth_denied(status=400)
    try:
        pair = rotate_verified_refresh(values["refresh"])
    except OperationalCoreDenied:
        return _deny()
    return native_json_response({
        "status": "authenticated", "access": pair[0], "refresh": pair[1],
    })


@csrf_exempt
def revoke(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    values = parse_native_json(request, ("refresh",))
    if values is None:
        return native_auth_denied(status=400)
    try:
        revoke_verified_device(values["refresh"])
    except OperationalCoreDenied:
        return _deny()
    return native_json_response({"status": "revoked"})


def me(request):
    blocked = _guard(request, "GET")
    if blocked is not None:
        return blocked
    header = request.META.get("HTTP_AUTHORIZATION")
    if (type(header) is not str or not header.startswith("Bearer ")
            or header.count(" ") != 1):
        return _deny()
    try:
        user = validate_verified_access(header[7:])
    except OperationalCoreDenied:
        return _deny()
    return native_json_response({"authenticated": True, "user_id": user.pk})
