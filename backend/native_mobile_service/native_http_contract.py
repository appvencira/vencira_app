"""Strict native mobile JSON wire boundary, independent of token issuer.

Reusable by a future reviewed operational service, but THIS MODULE does not
authenticate, issue credentials, enable bearer auth or register URLs. The
existing I8-D synthetic endpoints use this same contract in their isolated lab.
"""
import json

from django.http import JsonResponse


MAX_NATIVE_JSON_BODY = 4096


class NativeJsonInvalid(ValueError):
    """Generic validation failure without echoing credentials or payloads."""


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise NativeJsonInvalid()
        result[key] = value
    return result


def _reject_constant(_):
    raise NativeJsonInvalid()


def parse_native_json(request, fields):
    """Read only exact string-key JSON objects with canonical unique keys.

    Does not validate account/password/token semantics: the issuer must apply
    its own identity, MFA, audit, throttle and session fences before issuing.
    """
    if (
        type(fields) not in (tuple, frozenset)
        or not fields
        or any(type(name) is not str or not name for name in fields)
        or len(set(fields)) != len(fields)
        or request.content_type != "application/json"
    ):
        return None
    try:
        body = request.body
    except Exception:
        return None
    if not body or len(body) > MAX_NATIVE_JSON_BODY:
        return None
    try:
        value = json.loads(
            body.decode("utf-8", errors="strict"),
            object_pairs_hook=_unique_object,
            parse_constant=_reject_constant,
        )
    except (UnicodeError, ValueError, TypeError, RecursionError):
        return None
    if type(value) is not dict or set(value) != set(fields):
        return None
    if any(type(value[name]) is not str for name in fields):
        return None
    return value


def native_json_response(value, *, status=200):
    """No-store native JSON response; no tokens/cookies are set here."""
    result = JsonResponse(value, status=status)
    result["Cache-Control"] = "no-store, max-age=0"
    result["Pragma"] = "no-cache"
    result["X-Content-Type-Options"] = "nosniff"
    return result


def native_auth_denied(*, status=401):
    return native_json_response(
        {"error": "native_auth_unavailable"}, status=status,
    )
