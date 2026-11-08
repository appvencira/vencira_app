"""I8-D synthetic native JSON boundary; unreachable from operational URLs.

The lab-only key is injected server-side; request clients can never choose
TOTP key material or a verification timestamp. No production release implied.
"""
import json
import os
import uuid

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt

from .candidate_challenge_store import CandidateChallengeDenied
from .candidate_two_step_issuer import (
    candidate_mfa_challenge_to_session, candidate_password_to_challenge,
)
from .g14_admission import CandidateAdmissionDenied
from .g5_audit import MobileAuditDenied
from .g5_throttle import CandidateThrottleDenied
from .session_store import (
    MobileTokenDenied, revoke_candidate_device,
    rotate_candidate_refresh, validate_candidate_access,
)

_LIMIT = 4096


def _response(value, code=200):
    r = JsonResponse(value, status=code)
    r["Cache-Control"] = "no-store, max-age=0"
    r["Pragma"] = "no-cache"
    r["X-Content-Type-Options"] = "nosniff"
    return r


def _deny(code=401):
    return _response({"error": "native_auth_unavailable"}, code)


def _guard(request, method):
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and not settings.VENCIRA_NATIVE_BEARER_ENABLED
        and "native_mobile_service" in settings.INSTALLED_APPS
        and os.getenv("VENCIRA_I8D_HTTP_LAB") == "1"
        and settings.ROOT_URLCONF == "native_mobile_service.test_i8d_urls"
    ):
        return _deny(404)
    if request.method != method:
        return _deny(405)
    if request.META.get("HTTP_COOKIE") or request.META.get("HTTP_ORIGIN"):
        return _deny(403)
    if request.META.get("HTTP_AUTHORIZATION") and method == "POST":
        return _deny(403)
    return None


def _payload(request, fields):
    if request.content_type != "application/json":
        return None
    raw = request.body
    if len(raw) > _LIMIT:
        return None
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeError, ValueError):
        return None
    if type(value) is not dict or set(value) != set(fields):
        return None
    if any(type(value[k]) is not str for k in fields):
        return None
    return value


def _pair(tokens):
    a, r = tokens
    return _response({"status": "authenticated", "access": a, "refresh": r})


def _lab_keys():
    # NEVER take this from HTTP. In real HTTP no test-only keys may be used.
    secret = os.getenv("VENCIRA_I8D_MFA_KEY", "")
    if len(secret) != 44:
        raise CandidateChallengeDenied()
    return [secret]


@csrf_exempt
def password(request):
    rejected = _guard(request, "POST")
    if rejected is not None:
        return rejected
    data = _payload(request, {"username", "password"})
    if data is None:
        return _deny(400)
    try:
        challenge = candidate_password_to_challenge(
            username=data["username"], password=data["password"],
            request_meta=request.META, event_id=uuid.uuid4(),
        )
    except (CandidateChallengeDenied, CandidateAdmissionDenied, MobileAuditDenied, CandidateThrottleDenied):
        return _deny()
    if challenge is None:
        return _deny()
    return _response({"status": "mfa_required", "challenge": challenge})


@csrf_exempt
def mfa(request):
    rejected = _guard(request, "POST")
    if rejected is not None:
        return rejected
    data = _payload(request, {"challenge", "code"})
    if data is None:
        return _deny(400)
    try:
        pair = candidate_mfa_challenge_to_session(
            wire=data["challenge"], code=data["code"], keys=_lab_keys(),
            event_id=uuid.uuid4(),
        )
    except (CandidateChallengeDenied, MobileTokenDenied, MobileAuditDenied, ValueError):
        return _deny()
    if pair is None:
        return _deny()
    return _pair(pair)


@csrf_exempt
def refresh(request):
    rejected = _guard(request, "POST")
    if rejected is not None:
        return rejected
    data = _payload(request, {"refresh"})
    if data is None:
        return _deny(400)
    try:
        return _pair(rotate_candidate_refresh(data["refresh"]))
    except (MobileTokenDenied, ValueError):
        return _deny()


@csrf_exempt
def revoke(request):
    rejected = _guard(request, "POST")
    if rejected is not None:
        return rejected
    data = _payload(request, {"refresh"})
    if data is None:
        return _deny(400)
    try:
        revoke_candidate_device(data["refresh"])
    except (MobileTokenDenied, ValueError):
        return _deny()
    return _response({"status": "revoked"})


def me(request):
    rejected = _guard(request, "GET")
    if rejected is not None:
        return rejected
    value = request.META.get("HTTP_AUTHORIZATION", "")
    if type(value) is not str or not value.startswith("Bearer ") or value.count(" ") != 1:
        return _deny()
    try:
        user = validate_candidate_access(value[7:])
    except (MobileTokenDenied, ValueError):
        return _deny()
    return _response({"authenticated": True, "user_id": user.pk})
