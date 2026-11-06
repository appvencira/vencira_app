"""G5 key-versioning policy prototype, isolated from candidate session persistence.

No keys are loaded here: trusted caller injects independent high-entropy bytes.
This module is NOT wired to HTTP, Django SECRET_KEY, token issuing or database.
"""
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import hmac
import re

_KEY_ID = re.compile(r"\A[a-z][a-z0-9_-]{0,19}\Z")
_DIGEST = re.compile(r"\Ak1:([a-z][a-z0-9_-]{0,19}):([0-9a-f]{64})\Z")
PURPOSES = frozenset({"mobile-access", "mobile-refresh", "mobile-audit", "mobile-throttle"})


class CandidateKeyDenied(ValueError):
    """Fail closed without exposing cryptographic key contents."""


@dataclass(frozen=True)
class CandidateKey:
    key_id: str
    material: bytes
    verify_until: datetime | None = None

    def __post_init__(self):
        if not isinstance(self.key_id, str) or not _KEY_ID.fullmatch(self.key_id):
            raise CandidateKeyDenied()
        if type(self.material) is not bytes or len(self.material) < 32:
            raise CandidateKeyDenied()
        if self.verify_until is not None and (
            not isinstance(self.verify_until, datetime)
            or self.verify_until.tzinfo is None
            or self.verify_until.utcoffset() is None
        ):
            raise CandidateKeyDenied()


class CandidateKeyring:
    """One signing key + explicitly bounded verification-only predecessors."""

    def __init__(self, *, active: CandidateKey, previous=()):
        if not isinstance(active, CandidateKey) or active.verify_until is not None:
            raise CandidateKeyDenied()
        keys = (active, *tuple(previous))
        if any(not isinstance(item, CandidateKey) for item in keys):
            raise CandidateKeyDenied()
        if len(keys) > 4 or len({item.key_id for item in keys}) != len(keys):
            raise CandidateKeyDenied()
        if any(item.verify_until is None for item in keys[1:]):
            raise CandidateKeyDenied()
        if len({item.material for item in keys}) != len(keys):
            raise CandidateKeyDenied()
        self._active = active
        self._keys = {item.key_id: item for item in keys}

    @staticmethod
    def _mac(key, purpose, value):
        if purpose not in PURPOSES or type(value) is not bytes or not value:
            raise CandidateKeyDenied()
        payload = b"vencira:g5:k1:" + purpose.encode("ascii") + b":" + value
        return hmac.new(key.material, payload, hashlib.sha256).hexdigest()

    def digest(self, *, purpose: str, value: bytes) -> str:
        digest = self._mac(self._active, purpose, value)
        return f"k1:{self._active.key_id}:{digest}"

    def verify(self, *, purpose: str, value: bytes, stored: str, now=None) -> bool:
        if type(stored) is not str:
            return False
        match = _DIGEST.fullmatch(stored)
        if match is None:
            return False
        key = self._keys.get(match.group(1))
        if key is None:
            return False
        if now is None:
            now = datetime.now(timezone.utc)
        if not isinstance(now, datetime) or now.tzinfo is None or now.utcoffset() is None:
            raise CandidateKeyDenied()
        if key.verify_until is not None and now >= key.verify_until:
            return False
        try:
            expected = self._mac(key, purpose, value)
        except CandidateKeyDenied:
            return False
        return hmac.compare_digest(expected, match.group(2))
