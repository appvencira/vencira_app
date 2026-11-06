"""N1 native credentials: opaque high-entropy values, digest-only persistence.

NOT a login endpoint, issuer or DRF authentication backend. Values become
meaningful ONLY after a separately reviewed, persistent session/revocation
record and per-request authoritative identity validation are implemented.

The UUID is a random lookup handle, not proof of authorization. The secret
part provides authentication; only an HMAC digest may be stored server-side.
"""
import base64
import hmac
import re
import secrets
import uuid

from django.utils.crypto import salted_hmac


_TOKEN = re.compile(r"\Av1\.(a|r)\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})\Z")
_DIGEST = re.compile(r"\A[0-9a-f]{64}\Z")


class NativeMobileTokenInvalid(ValueError):
    """Invalid native credential; do not reveal token material to the client."""


def make_native_token(*, kind: str, session_id: uuid.UUID) -> str:
    """A 256-bit random bearer. 'a' access or 'r' refresh, never reusable."""
    if kind not in ("a", "r") or not isinstance(session_id, uuid.UUID):
        raise NativeMobileTokenInvalid()
    random_part = base64.urlsafe_b64encode(
        secrets.token_bytes(32),
    ).decode("ascii").rstrip("=")
    return f"v1.{kind}.{session_id.hex}.{random_part}"


def parse_native_token(token: str, *, kind: str) -> uuid.UUID:
    """Return the UNTRUSTED lookup handle after strict canonical parsing.

    A parsed handle never authenticates a user. Digest, expiry, rotation and
    server-side revocation MUST still be checked under DB locks.
    """
    if type(token) is not str or kind not in ("a", "r"):
        raise NativeMobileTokenInvalid()
    result = _TOKEN.fullmatch(token)
    if result is None or result.group(1) != kind:
        raise NativeMobileTokenInvalid()
    encoded = result.group(3)
    try:
        raw = base64.urlsafe_b64decode(encoded + "=")
    except (ValueError, base64.binascii.Error) as exc:
        raise NativeMobileTokenInvalid() from exc
    if len(raw) != 32 or base64.urlsafe_b64encode(raw).decode(
        "ascii",
    ).rstrip("=") != encoded:
        raise NativeMobileTokenInvalid()
    return uuid.UUID(hex=result.group(2))


def native_token_digest(token: str, *, kind: str) -> str:
    """Domain-separated HMAC-SHA256. Store ONLY the returned digest."""
    parse_native_token(token, kind=kind)
    return salted_hmac(
        f"vencira.mobile.opaque.{kind}.v1",
        token,
        algorithm="sha256",
    ).hexdigest()


def matches_native_token(token: str, *, kind: str, stored_digest: str) -> bool:
    """Never authenticate using the UUID alone, and reject corrupt digests."""
    if type(stored_digest) is not str or not _DIGEST.fullmatch(stored_digest):
        return False
    try:
        candidate = native_token_digest(token, kind=kind)
    except NativeMobileTokenInvalid:
        return False
    return hmac.compare_digest(candidate, stored_digest)
