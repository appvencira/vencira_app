"""D22 ephemeral HTTPS-facing server-custodied native issuer wiring.

This URL handler is only reachable through test_d22_urls in a disposable
PostgreSQL laboratory. No operational routing, cookies, release or MFA rollout.
It calls the real server-custody composition rather than taking MFA keys from
the HTTP request or the I8-D lab key variable.
"""
import os

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.views.decorators.csrf import csrf_exempt

from .candidate_challenge_store import CandidateChallengeDenied
from .g14_admission import CandidateAdmissionDenied
from .g5_audit import MobileAuditDenied
from .g5_throttle import CandidateThrottleDenied
from .native_http_contract import (
    native_auth_denied, native_json_response, parse_native_json,
)
from .native_server_custody_issuer import (
    NativeServerIssuerUnavailable,
    begin_native_password, complete_native_mfa,
    begin_native_recovery, complete_native_recovery,
)
from .session_store import MobileTokenDenied, revoke_candidate_device, validate_candidate_access, _find
from .native_workspace_reader import NativeWorkspaceDenied, read_native_workspace_renewals


def _guard(request, method):
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and settings.VENCIRA_NATIVE_BEARER_ENABLED is False
        and "native_mobile_service" in settings.INSTALLED_APPS
        and os.getenv("VENCIRA_D22_HTTP_LAB") == "1"
        and settings.ROOT_URLCONF == "native_mobile_service.test_d22_urls"
    ):
        return native_auth_denied(status=404)
    if request.method != method:
        return native_auth_denied(status=405)
    if (
        not request.is_secure()
        or request.META.get("HTTP_COOKIE")
        or request.META.get("HTTP_ORIGIN")
        or request.META.get("HTTP_REFERER")
    ):
        return native_auth_denied(status=403)
    if method == "POST" and request.META.get("HTTP_AUTHORIZATION"):
        return native_auth_denied(status=403)
    return None


def _credentials(request, fields):
    return parse_native_json(request, tuple(fields))


def _deny():
    return native_auth_denied(status=401)


def _challenge(challenge):
    if not isinstance(challenge, str) or not challenge:
        return _deny()
    return native_json_response({"status": "mfa_required", "challenge": challenge})


def _issued(pair):
    if not pair:
        return _deny()
    access, refresh = pair
    return native_json_response(
        {"status": "authenticated", "access": access, "refresh": refresh},
    )


_DENIED = (
    NativeServerIssuerUnavailable, CandidateChallengeDenied,
    CandidateAdmissionDenied, MobileAuditDenied, CandidateThrottleDenied,
    MobileTokenDenied, ValueError,
)


@csrf_exempt
def password(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    fields = _credentials(request, ("username", "password"))
    if fields is None:
        return native_auth_denied(status=400)
    try:
        return _challenge(begin_native_password(
            username=fields["username"], password=fields["password"],
            request_meta=request.META,
        ))
    except _DENIED:
        return _deny()


@csrf_exempt
def mfa(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    fields = _credentials(request, ("challenge", "code"))
    if fields is None:
        return native_auth_denied(status=400)
    try:
        return _issued(complete_native_mfa(
            challenge=fields["challenge"], code=fields["code"],
        ))
    except _DENIED:
        return _deny()


@csrf_exempt
def recover_password(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    fields = _credentials(request, ("username", "password"))
    if fields is None:
        return native_auth_denied(status=400)
    try:
        return _challenge(begin_native_recovery(
            username=fields["username"], password=fields["password"],
            request_meta=request.META,
        ))
    except _DENIED:
        return _deny()


@csrf_exempt
def recover_mfa(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    fields = _credentials(request, ("challenge", "code"))
    if fields is None:
        return native_auth_denied(status=400)
    try:
        return _issued(complete_native_recovery(
            challenge=fields["challenge"], code=fields["code"],
        ))
    except _DENIED:
        return _deny()


@csrf_exempt
def revoke(request):
    blocked = _guard(request, "POST")
    if blocked is not None:
        return blocked
    fields = _credentials(request, ("refresh",))
    if fields is None:
        return native_auth_denied(status=400)
    try:
        revoke_candidate_device(fields["refresh"])
    except _DENIED:
        return _deny()
    return native_json_response({"status": "revoked"})


def me(request):
    blocked = _guard(request, "GET")
    if blocked is not None:
        return blocked
    header = request.META.get("HTTP_AUTHORIZATION")
    if (
        type(header) is not str or not header.startswith("Bearer ")
        or header.count(" ") != 1
    ):
        return _deny()
    try:
        user = validate_candidate_access(header[7:])
    except _DENIED:
        return _deny()
    return native_json_response({"authenticated": True, "user_id": user.pk})


def workspace_renewals(request, workspace_id):
    """D24 lab-only page with locked account, device, membership, row scope.

    The account lock precedes the device lock: account-wide recovery follows
    the same ordering and cannot invalidate the token during this SQL read.
    Device revoke takes the locked device row. HTTP response is built while
    locks remain held; membership and assignment changes wait for commit.
    """
    blocked = _guard(request, "GET")
    if blocked is not None:
        return blocked
    header = request.META.get("HTTP_AUTHORIZATION")
    if (
        type(header) is not str
        or not header.startswith("Bearer ")
        or header.count(" ") != 1
    ):
        return _deny()
    page_raw = request.GET.get("offset", "0")
    if (
        not page_raw.isascii()
        or not page_raw.isdecimal()
        or len(page_raw) > 5
        or str(int(page_raw)) != page_raw
    ):
        return native_auth_denied(status=400)
    offset = int(page_raw)
    if offset > 10000:
        return native_auth_denied(status=400)
    token = header[7:]
    try:
        # Preflight identifies only which account lock should be acquired.
        # Identity and revocation are checked AGAIN after locking device row.
        identity = validate_candidate_access(token)
        with transaction.atomic():
            user = get_user_model().objects.select_for_update().filter(
                pk=identity.pk, is_active=True,
            ).first()
            if user is None:
                raise MobileTokenDenied()
            device = _find(token, "a", lock=True)
            if device.user_id != user.pk:
                raise MobileTokenDenied()
            # validate_candidate_access checks access expiry, digest, MFA epoch,
            # credential version and account generation while locks are held.
            validate_candidate_access(token)
            result = read_native_workspace_renewals(
                user=user, workspace_id=workspace_id, offset=offset,
            )
            response = native_json_response(result)
        return response
    except (MobileTokenDenied, NativeWorkspaceDenied, ValueError):
        return _deny()
