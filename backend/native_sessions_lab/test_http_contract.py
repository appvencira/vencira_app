"""TEST-ONLY native HTTP boundary, never added to config.urls or reminders.urls.

These views are resolved solely by override_settings(ROOT_URLCONF=
"native_sessions_lab.test_urls") in the disposable lab. Production code must
NOT import or register this module. A standalone runtime guard denies requests
even if someone mistakenly includes a URL outside the test environment.
"""
import json
import uuid


from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .login_rules import (
    NativeLoginLabDenied, begin_native_login_lab, finish_native_mfa_lab,
)
from .session_rules import (
    SessionLabDenied, revoke_device, rotate_refresh, validate_access,
)

MAX_REQUEST_BYTES = 4096


def _result(data, status=200):
    response = JsonResponse(data, status=status)
    response["Cache-Control"] = "no-store, max-age=0"
    response["Pragma"] = "no-cache"
    return response


def _denied(status=401):
    return _result({"error": "native_auth_unavailable"}, status=status)


def _guard(request, *, post=True):
    if not (settings.VENCIRA_ENV == "test" and
            settings.VENCIRA_NATIVE_SESSION_LAB and
            "native_sessions_lab" in settings.INSTALLED_APPS):
        return _denied(404)
    if request.method != ("POST" if post else "GET"):
        return _denied(405)
    # Native applications send neither web-session cookies nor browser Origin.
    # This test contract deliberately never consumes Django web credentials.
    if request.META.get("HTTP_COOKIE") or request.META.get("HTTP_ORIGIN"):
        return _denied(403)
    return None


def _payload(request, keys):
    ct = request.headers.get("Content-Type", "").lower().split(";", 1)[0].strip()
    if ct != "application/json":
        return None
    try:
        if len(request.body) > MAX_REQUEST_BYTES:
            return None
        value = json.loads(request.body.decode("utf-8"))
    except (UnicodeError, ValueError):
        return None
    if not isinstance(value, dict) or set(value) != set(keys):
        return None
    if any(type(value[key]) is not str for key in keys):
        return None
    return value


def _issued(tokens):
    access, refresh = tokens
    return _result({
        "status": "authenticated", "access": access, "refresh": refresh,
    })


@csrf_exempt
def password(request):
    denial = _guard(request)
    if denial is not None:
        return denial
    payload = _payload(request, {"username", "password"})
    if payload is None:
        return _denied(400)
    try:
        mode, result = begin_native_login_lab(
            payload["username"], payload["password"],
        )
        if mode == "mfa":
            return _result({"status": "mfa_required", "challenge": result})
        return _issued(result)
    except NativeLoginLabDenied:
        return _denied()


@csrf_exempt
def mfa(request):
    denial = _guard(request)
    if denial is not None:
        return denial
    payload = _payload(request, {"challenge", "code"})
    if payload is None:
        return _denied(400)
    try:
        return _issued(finish_native_mfa_lab(
            payload["challenge"], payload["code"],
        ))
    except NativeLoginLabDenied:
        return _denied()


@csrf_exempt
def refresh(request):
    denial = _guard(request)
    if denial is not None:
        return denial
    payload = _payload(request, {"refresh"})
    if payload is None:
        return _denied(400)
    try:
        return _issued(rotate_refresh(payload["refresh"]))
    except SessionLabDenied:
        return _denied()


@csrf_exempt
def revoke(request):
    denial = _guard(request)
    if denial is not None:
        return denial
    payload = _payload(request, {"refresh"})
    if payload is None:
        return _denied(400)
    try:
        revoke_device(payload["refresh"])
        return _result({"status": "revoked"})
    except SessionLabDenied:
        return _denied()


def me(request):
    denial = _guard(request, post=False)
    if denial is not None:
        return denial
    header = request.headers.get("Authorization", "")
    if (not header.startswith("Bearer ") or
            header.count(" ") != 1):
        return _denied()
    try:
        user = validate_access(header[7:])
    except SessionLabDenied:
        return _denied()
    return _result({"authenticated": True, "user_id": user.pk})


def workspace_renewals(request, workspace_id):
    """Read-only mobile Bearer scope; lab-only.

    Authenticate from the verified token, then reuse the exact membership and
    visible-renewals restrictions already applied by the web API. Never look
    up a renewal outside that filtered queryset, and do not expose PII in this
    synthetic contract. This is not installed in operational routing.
    """
    denial = _guard(request, post=False)
    if denial is not None:
        return denial
    if request.GET:
        return _denied(400)
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer ") or header.count(" ") != 1:
        return _denied()
    try:
        user = validate_access(header[7:])
    except SessionLabDenied:
        return _denied()

    from reminders.models import WorkspaceMember
    from reminders.views import _visible_renewals

    if not isinstance(workspace_id, uuid.UUID):
        return _denied(404)
    member = WorkspaceMember.objects.filter(
        workspace_id=workspace_id, user_id=user.pk,
    ).first()
    if member is None:
        return _denied(404)
    queryset = _visible_renewals(member).order_by("expires_on", "pk")
    # Limit both item count and response body; deliberately omit names,
    # policy number, phone, notes and other sensitive contract fields.
    rows = list(queryset.values("id", "expires_on", "status")[:50])
    return _result({
        "workspace_id": str(workspace_id),
        "results": [{
            "id": str(row["id"]),
            "expires_on": row["expires_on"].isoformat(),
            "status": row["status"],
        } for row in rows],
    })
