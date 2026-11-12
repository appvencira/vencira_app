"""D27 independent native password→MFA→session core (not an HTTP issuer).

This does NOT import candidate_* issuers, session_store, or their test gates.
It deliberately remains laboratory-only until a separately reviewed operational
transport, token lifecycle, key custody, recovery and release are implemented.
All authority is derived from Django password/MFA state under PG locks.
"""
import base64
import hashlib
import hmac
import ipaddress
import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

from reminders.mfa_key_config import load_mfa_keys
from reminders.mfa_store import consume_totp
from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from reminders.native_mobile_identity_gate import (
    mobile_credential_version, require_mobile_identity_gate,
)
from reminders.native_mobile_token_primitives import make_native_token, native_token_digest

from .models import (
    MobileAccountFence, MobileAuthAttemptBucket, MobileAuthAuditEvent,
    MobileDeviceSession, MobilePendingChallenge,
)

_TTL = timedelta(minutes=5)
_ACCESS = timedelta(minutes=5)
_REFRESH = timedelta(days=30)
_WINDOW = timedelta(minutes=15)
_BLOCK = timedelta(minutes=15)
_LIMITS = {"account": 5, "ip": 20}
_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"


class OperationalCoreDenied(PermissionError):
    """Uniform denial; caller cannot infer account or MFA state."""


def _context():
    # Remove this constraint ONLY when actual production dependencies, auth
    # endpoints, independent gates and explicit release are established.
    if not (
        settings.VENCIRA_ENV == "test"
        and settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        and not settings.VENCIRA_NATIVE_BEARER_ENABLED
        and "native_mobile_service" in settings.INSTALLED_APPS
    ):
        raise OperationalCoreDenied()
    audit = getattr(settings, "VENCIRA_D27_CORE_AUDIT_KEY", None)
    abuse = getattr(settings, "VENCIRA_D27_CORE_ABUSE_KEY", None)
    if not (type(audit) is str and len(audit) >= 32
            and type(abuse) is str and len(abuse) >= 32):
        raise OperationalCoreDenied()
    try:
        keys = load_mfa_keys()
    except (ValueError, OSError) as exc:
        raise OperationalCoreDenied() from exc
    return audit.encode(), abuse.encode(), keys


def _digest(key, domain, value):
    return hmac.new(key, (domain + value).encode("utf-8"), hashlib.sha256).hexdigest()


def _event(key, event_type, actor):
    MobileAuthAuditEvent.objects.create(
        event_id=uuid.uuid4(),
        event_type=event_type,
        actor_digest=_digest(key, "d27:audit:", actor),
    )


def _admit(key, username, remote_addr):
    # Ignore HTTP forwarding headers until a separately reviewed reverse-proxy
    # identity provider is configured. The port accepts the direct peer IP.
    if type(remote_addr) is not str or len(remote_addr) > 45:
        raise OperationalCoreDenied()
    try:
        canonical_ip = str(ipaddress.ip_address(remote_addr))
    except ValueError as exc:
        raise OperationalCoreDenied() from exc
    identities = sorted((
        ("account", _digest(key, "d27:account:", username)),
        ("ip", _digest(key, "d27:ip:", canonical_ip)),
    ))
    now = timezone.now()
    allowed = True
    with transaction.atomic():
        for scope, digest in identities:
            row, _ = MobileAuthAttemptBucket.objects.get_or_create(
                scope=scope, subject_digest=digest,
                defaults={"window_started_at": now},
            )
            row = MobileAuthAttemptBucket.objects.select_for_update().get(pk=row.pk)
            if row.blocked_until is not None and row.blocked_until > now:
                allowed = False
                continue
            if row.window_started_at + _WINDOW <= now:
                row.window_started_at = now
                row.attempt_count = 0
                row.blocked_until = None
            row.attempt_count += 1
            if row.attempt_count >= _LIMITS[scope]:
                row.blocked_until = now + _BLOCK
                allowed = False
            row.save(update_fields=[
                "window_started_at", "attempt_count", "blocked_until",
            ])
    return allowed


def _mfa_state(user):
    state = UserMfaState.objects.select_for_update().filter(
        user=user, enabled=True,
    ).first()
    if state is None:
        raise OperationalCoreDenied()
    if MfaAdministrativeRecoveryCase.objects.filter(
        subject=user,
        status=MfaAdministrativeRecoveryCase.Status.PENDING,
    ).exists():
        raise OperationalCoreDenied()
    return state


def _issue_wire():
    challenge_id = uuid.uuid4()
    random = secrets.token_bytes(32)
    encoded = base64.urlsafe_b64encode(random).decode("ascii").rstrip("=")
    return f"oc1.{challenge_id.hex}.{encoded}", challenge_id, hashlib.sha256(random).hexdigest()


def _parse_wire(wire):
    if (type(wire) is not str or len(wire) != 80
            or not wire.startswith("oc1.")):
        raise OperationalCoreDenied()
    parts = wire.split(".")
    if (len(parts) != 3 or len(parts[1]) != 32
            or any(c not in "0123456789abcdef" for c in parts[1])
            or len(parts[2]) != 43
            or any(c not in _ALPHABET for c in parts[2])):
        raise OperationalCoreDenied()
    try:
        random = base64.urlsafe_b64decode(parts[2] + "=")
    except (ValueError, base64.binascii.Error) as exc:
        raise OperationalCoreDenied() from exc
    if (len(random) != 32 or
            base64.urlsafe_b64encode(random).decode("ascii").rstrip("=") != parts[2]):
        raise OperationalCoreDenied()
    return uuid.UUID(hex=parts[1]), hashlib.sha256(random).hexdigest()


def begin_verified_password(*, username, password, remote_addr):
    """Return an opaque challenge, or None; NEVER return tokens at this stage.

    Authentication is checked only after account/IP antiabuse and audit custody.
    """
    audit, abuse, _ = _context()
    if (type(username) is not str or not username or len(username) > 150
            or username != username.strip()
            or type(password) is not str or not password or len(password) > 4096):
        raise OperationalCoreDenied()
    allowed = _admit(abuse, username, remote_addr)
    if not allowed:
        with transaction.atomic():
            _event(audit, "auth_denied", username)
        return None
    with transaction.atomic():
        User = get_user_model()
        if User.USERNAME_FIELD != "username":
            raise OperationalCoreDenied()
        user = User.objects.select_for_update().filter(
            username=username, is_active=True,
        ).first()
        if user is None or not user.check_password(password):
            _event(audit, "auth_denied", username)
            return None
        try:
            state = _mfa_state(user)
        except OperationalCoreDenied:
            _event(audit, "auth_denied", username)
            return None
        generation = MobileAccountFence.objects.filter(
            user_id=user.pk,
        ).values_list("generation", flat=True).first() or 0
        wire, challenge_id, digest = _issue_wire()
        MobilePendingChallenge.objects.create(
            id=challenge_id, user=user, secret_digest=digest,
            credential_version=mobile_credential_version(user),
            mfa_epoch=state.session_epoch, auth_generation=generation,
            expires_at=timezone.now() + _TTL,
        )
        return wire


def complete_verified_mfa(*, challenge, code):
    """Verify authoritative MFA and atomically issue digested opaque tokens.

    No HTTP route invokes this. Wrong codes retain anti-replay state in MFA
    storage; success consumes the challenge and records the audit in one tx.
    """
    audit, _, keys = _context()
    if (type(code) is not str or len(code) != 6 or not code.isascii()
            or not code.isdecimal()):
        raise OperationalCoreDenied()
    challenge_id, expected_digest = _parse_wire(challenge)
    with transaction.atomic():
        user_id = MobilePendingChallenge.objects.filter(
            pk=challenge_id,
        ).values_list("user_id", flat=True).first()
        if user_id is None:
            raise OperationalCoreDenied()
        user = get_user_model().objects.select_for_update().filter(
            pk=user_id, is_active=True,
        ).first()
        if user is None:
            raise OperationalCoreDenied()
        state = _mfa_state(user)
        row = MobilePendingChallenge.objects.select_for_update().filter(
            pk=challenge_id, user=user,
        ).first()
        generation = MobileAccountFence.objects.filter(
            user=user,
        ).values_list("generation", flat=True).first() or 0
        now = timezone.now()
        if (row is None or row.consumed_at is not None or row.expires_at <= now
                or row.credential_version != mobile_credential_version(user)
                or row.mfa_epoch != state.session_epoch
                or row.auth_generation != generation
                or not hmac.compare_digest(row.secret_digest, expected_digest)):
            raise OperationalCoreDenied()
        if not consume_totp(user.pk, code, keys=keys):
            _event(audit, "auth_denied", user.username)
            return None
        require_mobile_identity_gate(
            user=user, verified_mfa=True,
            asserted_mfa_epoch=state.session_epoch,
            asserted_credential_version=row.credential_version,
        )
        row.consumed_at = now
        row.save(update_fields=["consumed_at"])
        session = MobileDeviceSession(
            user=user, access_digest="", refresh_digest="",
            credential_version=row.credential_version,
            auth_generation=generation,
            verified_mfa=True, mfa_epoch=state.session_epoch,
            access_expires_at=now + _ACCESS,
            refresh_expires_at=now + _REFRESH,
        )
        access = make_native_token(kind="a", session_id=session.id)
        refresh = make_native_token(kind="r", session_id=session.id)
        session.access_digest = native_token_digest(access, kind="a")
        session.refresh_digest = native_token_digest(refresh, kind="r")
        session.save(force_insert=True)
        _event(audit, "auth_verified", user.username)
        return access, refresh
