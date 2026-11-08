"""I8-K recovery-only HTTP JSON for a disposable PG17 TLS laboratory.

Never imported by config.urls; access is limited to an explicit isolated
ROOT_URLCONF and a dedicated environment gate. No trusted browser session.
"""
import os
import uuid

from django.conf import settings
from django.views.decorators.csrf import csrf_exempt

from .candidate_challenge_store import CandidateChallengeDenied
from .candidate_recovery_issuer import (
    recovery_password_to_challenge, recovery_mfa_to_atomic_session,
)
from .g14_admission import CandidateAdmissionDenied
from .g5_audit import MobileAuditDenied
from .g5_throttle import CandidateThrottleDenied
from .session_store import (MobileTokenDenied, revoke_candidate_device, validate_candidate_access)
from .test_i8d_http_views import _deny, _payload, _response, _pair, _lab_keys


def _guard(request, method):
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and not settings.VENCIRA_NATIVE_BEARER_ENABLED
        and "native_mobile_service" in settings.INSTALLED_APPS
        and os.getenv("VENCIRA_I8K_RECOVERY_LAB") == "1"
        and settings.ROOT_URLCONF == "native_mobile_service.test_i8k_recovery_urls"
    ):
        return _deny(404)
    if request.method != method:
        return _deny(405)
    if request.META.get("HTTP_COOKIE") or request.META.get("HTTP_ORIGIN"):
        return _deny(403)
    if request.META.get("HTTP_AUTHORIZATION") and method == "POST":
        return _deny(403)
    return None


@csrf_exempt
def recover_password(request):
    denied = _guard(request, "POST")
    if denied is not None:
        return denied
    fields = _payload(request, {"username", "password"})
    if fields is None:
        return _deny(400)
    try:
        challenge = recovery_password_to_challenge(
            username=fields["username"], password=fields["password"],
            request_meta=request.META, event_id=uuid.uuid4(),
        )
    except (CandidateChallengeDenied, CandidateAdmissionDenied,
            MobileAuditDenied, CandidateThrottleDenied):
        return _deny()
    if challenge is None:
        return _deny()
    return _response({"status": "mfa_required", "challenge": challenge})


@csrf_exempt
def recover_mfa(request):
    denied = _guard(request, "POST")
    if denied is not None:
        return denied
    fields = _payload(request, {"challenge", "code"})
    if fields is None:
        return _deny(400)
    try:
        issued = recovery_mfa_to_atomic_session(
            wire=fields["challenge"], code=fields["code"],
            keys=_lab_keys(), event_id=uuid.uuid4(),
        )
    except (CandidateChallengeDenied, MobileTokenDenied, MobileAuditDenied,
            ValueError):
        return _deny()
    if issued is None:
        return _deny()
    return _pair(issued)



@csrf_exempt
def revoke(request):
    """Revoke only the holder of the exact refresh token, in the test lab."""
    denied = _guard(request, "POST")
    if denied is not None:
        return denied
    fields = _payload(request, {"refresh"})
    if fields is None:
        return _deny(400)
    try:
        revoke_candidate_device(fields["refresh"])
    except (MobileTokenDenied, ValueError):
        return _deny()
    return _response({"status": "revoked"})

def me(request):
    denied = _guard(request, "GET")
    if denied is not None:
        return denied
    bearer = request.META.get("HTTP_AUTHORIZATION", "")
    if type(bearer) is not str or not bearer.startswith("Bearer ") or bearer.count(" ") != 1:
        return _deny()
    try:
        user = validate_candidate_access(bearer[7:])
    except (MobileTokenDenied, ValueError):
        return _deny()
    return _response({"authenticated": True, "user_id": user.pk})
