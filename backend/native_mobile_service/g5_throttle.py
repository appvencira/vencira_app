"""G5 shared candidate throttle, using row locks on disposable PostgreSQL 17.

Not an HTTP login integration. All request identities are HMACed before storage.
The key must be supplied by isolated tests; no fallback to DJANGO_SECRET_KEY.
"""
import hashlib
import hmac
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .g5_network_identity import candidate_client_ip, UntrustedNetworkIdentity
from .models import MobileAuthAttemptBucket

WINDOW = timedelta(minutes=15)
BLOCK = timedelta(minutes=15)
LIMITS = {"account": 5, "ip": 20}


class CandidateThrottleDenied(Exception):
    """Uniform denial: no reason or account-existence disclosure."""


def _gate():
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and "native_mobile_service" in settings.INSTALLED_APPS
    ):
        raise CandidateThrottleDenied()
    key = getattr(settings, "VENCIRA_G5_ABUSE_KEY", None)
    if not isinstance(key, str) or len(key) < 32:
        raise CandidateThrottleDenied()
    return key.encode("utf-8")


def _digest(key, scope, value):
    return hmac.new(
        key, ("v1:g5-abuse:" + scope + ":" + value).encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def consume_candidate_auth_attempt(*, account_key, request_meta, trusted_proxy_ips=()):
    """Consume BOTH account and IP attempts atomically before checking credentials.

    Caller must pass a canonical account identifier with the same normalization
    for known and unknown accounts. The database transaction serializes attempts
    across workers. True only permits an upstream verification attempt; it does
    NOT assert that password or MFA was valid.
    """
    key = _gate()
    if (
        not isinstance(account_key, str)
        or not account_key
        or len(account_key) > 254
        or account_key != account_key.strip()
    ):
        raise CandidateThrottleDenied()
    try:
        client_ip = candidate_client_ip(
            request_meta, trusted_proxy_ips=trusted_proxy_ips,
        )
    except UntrustedNetworkIdentity as exc:
        raise CandidateThrottleDenied() from exc
    identities = sorted((
        ("account", _digest(key, "account", account_key)),
        ("ip", _digest(key, "ip", client_ip)),
    ))
    now = timezone.now()
    permitted = True
    with transaction.atomic():
        # Stable global ordering avoids inverted locks for intersecting pairs.
        for scope, digest in identities:
            row, _ = MobileAuthAttemptBucket.objects.get_or_create(
                scope=scope, subject_digest=digest,
                defaults={"window_started_at": now},
            )
            row = MobileAuthAttemptBucket.objects.select_for_update().get(pk=row.pk)
            if row.blocked_until is not None and row.blocked_until > now:
                permitted = False
                continue
            if row.window_started_at + WINDOW <= now:
                row.window_started_at = now
                row.attempt_count = 0
                row.blocked_until = None
            row.attempt_count += 1
            if row.attempt_count >= LIMITS[scope]:
                row.blocked_until = now + BLOCK
                permitted = False
            row.save(update_fields=[
                "window_started_at", "attempt_count", "blocked_until",
            ])
    return permitted
