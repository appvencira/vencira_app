"""G5 test-only minimal auth audit; no password, token, code, raw IP or username.

Caller owns idempotency UUID; repeating with changed payload fails closed.
No HTTP integration, retention automation, or external audit custody exists.
"""
import hashlib
import hmac
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import MobileAuthAuditEvent

EVENTS = frozenset({
    "auth_denied", "auth_verified", "refresh_rotated",
    "refresh_replay", "device_logout", "account_revoke",
})
RETENTION_DAYS = 30


class MobileAuditDenied(Exception):
    """Do not disclose actor existence or audit contents."""


def _key():
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and "native_mobile_service" in settings.INSTALLED_APPS
    ):
        raise MobileAuditDenied()
    secret = getattr(settings, "VENCIRA_G5_AUDIT_KEY", None)
    if not isinstance(secret, str) or len(secret) < 32:
        raise MobileAuditDenied()
    return secret.encode("utf-8")


def record_candidate_auth_event(
    *, event_id, event_type, actor=None, session_id=None,
):
    """Idempotent insert of an allowlisted minimal security event."""
    key = _key()
    if type(event_id) is not uuid.UUID or event_type not in EVENTS:
        raise MobileAuditDenied()
    if actor is not None and (
        not isinstance(actor, str) or not actor
        or len(actor) > 254 or actor != actor.strip()
    ):
        raise MobileAuditDenied()
    if session_id is not None and type(session_id) is not uuid.UUID:
        raise MobileAuditDenied()
    digest = (
        hmac.new(
            key, ("v1:g5-audit:" + actor).encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        if actor is not None else ""
    )
    with transaction.atomic():
        existing = MobileAuthAuditEvent.objects.select_for_update().filter(
            event_id=event_id,
        ).first()
        if existing is not None:
            if (
                existing.event_type != event_type
                or existing.actor_digest != digest
                or existing.session_id != session_id
            ):
                raise MobileAuditDenied()
            return existing, False
        return MobileAuthAuditEvent.objects.create(
            event_id=event_id, event_type=event_type,
            actor_digest=digest, session_id=session_id,
        ), True


def purge_candidate_auth_events(*, before=None):
    """Explicit lab-only retention task; never delete newer events."""
    _key()
    cutoff = timezone.now() - timedelta(days=RETENTION_DAYS)
    if before is not None:
        if timezone.is_naive(before) or before > cutoff:
            raise MobileAuditDenied()
        cutoff = before
    deleted, _ = MobileAuthAuditEvent.objects.filter(
        occurred_at__lt=cutoff,
    ).delete()
    return deleted
