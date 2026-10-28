"""Verification-only scanner verdict contract. Not an antivirus engine.

A trusted isolated scanner must be deployed separately before use. This module
verifies authenticity/integrity of signed results; it never releases files.
"""
import hashlib
import hmac
import json
import re
import uuid
from datetime import datetime, timezone

_ALLOWED = {"clean", "infected", "error"}
_DIGEST = re.compile(r"^[0-9a-f]{64}$")


def _canonical(body):
    return json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def verify_scan_verdict(*, payload, signature, verification_key, attachment,
                        now=None, max_age_seconds=600):
    """Fail closed for missing/malformed/untrusted/stale/mismatched attestations.

    verification_key is a separate service key, NEVER a Fernet or MFA key.
    This verifies only a claimed verdict; antivirus quality is independent.
    """
    if (not isinstance(payload, dict) or not isinstance(signature, str)
            or not isinstance(verification_key, bytes) or len(verification_key) < 32
            or not isinstance(max_age_seconds, int) or not 1 <= max_age_seconds <= 3600):
        return False
    required = {"object_key", "sha256", "verdict", "scanned_at", "engine"}
    if set(payload) != required:
        return False
    try:
        obj = uuid.UUID(payload["object_key"])
        digest = payload["sha256"]
        timestamp = payload["scanned_at"]
        if (obj.hex != attachment.storage_key.hex
                or not isinstance(digest, str) or not _DIGEST.fullmatch(digest)
                or not hmac.compare_digest(digest, attachment.sha256)
                or payload["verdict"] not in _ALLOWED or payload["verdict"] != "clean"
                or not isinstance(payload["engine"], str)
                or not 1 <= len(payload["engine"]) <= 80
                or not isinstance(timestamp, int) or isinstance(timestamp, bool)):
            return False
        current = int((now or datetime.now(timezone.utc)).timestamp())
        if timestamp > current + 30 or current - timestamp > max_age_seconds:
            return False
        expected = hmac.new(verification_key, _canonical(payload), hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)
    except (ValueError, TypeError, AttributeError, OverflowError):
        return False
