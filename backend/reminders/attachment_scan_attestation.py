"""Offline scanner-side attestation primitive; NOT imported by public API.

This function must run only in a segregated scanner process whose HMAC key
is independently provisioned. Successful signature never enables downloads.
"""
import hashlib
import hmac
import json
import re
from datetime import datetime, timezone

_DIGEST = re.compile(r"^[0-9a-f]{64}$")


def issue_scan_attestation(*, attachment, verdict, engine, signing_key, now=None):
    if (not isinstance(signing_key, bytes) or len(signing_key) < 32
            or verdict not in ("clean", "infected", "error")
            or not isinstance(engine, str) or not 1 <= len(engine) <= 80
            or not isinstance(attachment.sha256, str)
            or not _DIGEST.fullmatch(attachment.sha256)
            or getattr(attachment, "state", None) != "quarantined"):
        raise ValueError("Scanner attestation input invalid")
    timestamp = now if now is not None else datetime.now(timezone.utc)
    if not isinstance(timestamp, datetime) or timestamp.tzinfo is None:
        raise ValueError("Timestamp must be timezone aware")
    payload = {
        "object_key": str(attachment.storage_key),
        "sha256": attachment.sha256,
        "verdict": verdict,
        "scanned_at": int(timestamp.timestamp()),
        "engine": engine,
    }
    canonical = json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")
    signature = hmac.new(signing_key, canonical, hashlib.sha256).hexdigest()
    return payload, signature
