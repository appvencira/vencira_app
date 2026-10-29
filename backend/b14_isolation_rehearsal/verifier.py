"""B14A: verificador independiente, sin Django ni firmante."""
import json
import os
import re
import uuid
from datetime import datetime, timezone
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PublicKey,
)

DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"

assert "DJANGO_SECRET_KEY" not in os.environ
assert not any(k.startswith("POSTGRES_") for k in os.environ)

envelope = json.loads(
    Path("/exchange/evidence.json").read_text()
)
public = bytes.fromhex(
    Path("/exchange/public.hex").read_text()
)

FIELDS = {
    "version", "key_id", "object_key", "sha256",
    "verdict", "scanned_at", "engine",
}

def validate(payload, signature, trusted=True):
    try:
        if not trusted or type(payload) is not dict:
            return False
        if set(payload) != FIELDS:
            return False
        if type(payload["version"]) is not int or payload["version"] != 3:
            return False
        if payload["key_id"] != "b14a-synthetic":
            return False
        if type(payload["object_key"]) is not str:
            return False
        if str(uuid.UUID(payload["object_key"])) != payload["object_key"]:
            return False
        if type(payload["sha256"]) is not str:
            return False
        if not re.fullmatch(r"[0-9a-f]{64}", payload["sha256"]):
            return False
        if payload["sha256"] != __import__("hashlib").sha256(
            b"synthetic-b14a"
        ).hexdigest():
            return False
        if payload["verdict"] != "clean":
            return False
        if payload["engine"] != "b14a-synthetic-only":
            return False
        if type(payload["scanned_at"]) is not int:
            return False
        age = int(datetime.now(timezone.utc).timestamp()) - payload["scanned_at"]
        if not -30 <= age <= 600:
            return False
        if type(signature) is not str:
            return False
        if not re.fullmatch(r"[0-9a-f]{128}", signature):
            return False
        canonical = json.dumps(
            payload, sort_keys=True,
            separators=(",", ":"), ensure_ascii=True,
        ).encode("ascii")
        Ed25519PublicKey.from_public_bytes(public).verify(
            bytes.fromhex(signature),
            DOMAIN + canonical,
        )
        return True
    except (ValueError, KeyError, TypeError, InvalidSignature):
        return False

payload = envelope["payload"]
signature = envelope["signature"]

assert validate(payload, signature)
print("B14A_PUBLIC_VERIFY=OK")

assert not validate(payload, "0" * 128)
assert not validate({**payload, "verdict": "infected"}, signature)
assert not validate({**payload, "key_id": "unknown"}, signature)
assert not validate({**payload, "sha256": "0" * 64}, signature)
assert not validate(payload, signature, trusted=False)
print("B14A_NEGATIVE_CASES=OK")
