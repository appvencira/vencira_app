"""Candidate-only wire format for a native MFA challenge.

NO server-side persistence, password verification, issued session, endpoint,
or capability is provided by this module. A matching digest alone MUST NEVER
authorize MFA completion. Durable challenge custody and atomic consumption
must be implemented and reviewed separately.
"""
import base64
import hashlib
import hmac
import os
import re
import secrets
import uuid

_CHALLENGE_RE = re.compile(r"\Alc1\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})\Z")


class NativeChallengeMalformed(ValueError):
    """Uniform malformed challenge; does not indicate account existence."""


def _canonical_secret(encoded):
    try:
        raw = base64.b64decode(encoded + "=", altchars=b"-_", validate=True)
    except (ValueError, base64.binascii.Error):
        raise NativeChallengeMalformed() from None
    if len(raw) != 32 or base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii") != encoded:
        raise NativeChallengeMalformed()
    return raw


def new_candidate_challenge():
    """Return (wire token, challenge UUID, digest) with fresh 256-bit secret.

    Only test-only trusted code should call this. The wire token is a bearer
    secret; never place it in database, analytics, audit events, logs, or URL.
    """
    if os.environ.get("VENCIRA_ENV") != "test" or os.environ.get("VENCIRA_NATIVE_SERVICE_CANDIDATE") != "1":
        raise NativeChallengeMalformed()
    challenge_id = uuid.uuid4()
    raw = secrets.token_bytes(32)
    encoded = base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")
    wire = f"lc1.{challenge_id.hex}.{encoded}"
    return wire, challenge_id, _digest(challenge_id, raw)


def _digest(challenge_id, raw):
    return hashlib.sha256(b"vencira:mobile:challenge:v1:" + challenge_id.bytes + raw).hexdigest()


def parse_candidate_challenge(value):
    """Parse strictly canonical lc1 token; returns (UUID, secret bytes).

    Parsing does NOT validate issuance, expiration, account, MFA or replay.
    """
    if type(value) is not str:
        raise NativeChallengeMalformed()
    match = _CHALLENGE_RE.fullmatch(value)
    if match is None:
        raise NativeChallengeMalformed()
    try:
        challenge_id = uuid.UUID(hex=match.group(1))
    except ValueError:
        raise NativeChallengeMalformed() from None
    return challenge_id, _canonical_secret(match.group(2))


def matches_candidate_digest(wire, *, expected_id, stored_digest):
    """Constant-time proof of wire-secret equality only; not authentication."""
    challenge_id, secret = parse_candidate_challenge(wire)
    if type(expected_id) is not uuid.UUID or type(stored_digest) is not str:
        return False
    if len(stored_digest) != 64 or re.fullmatch(r"[0-9a-f]{64}", stored_digest) is None:
        return False
    id_matches = hmac.compare_digest(challenge_id.bytes, expected_id.bytes)
    secret_matches = hmac.compare_digest(_digest(challenge_id, secret), stored_digest)
    return id_matches & secret_matches
