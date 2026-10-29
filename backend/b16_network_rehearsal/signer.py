import hashlib
import hmac
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"
SIGN_DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"

assert os.geteuid() == 65532
assert not any(name.startswith("POSTGRES_") for name in os.environ)
assert "DJANGO_SECRET_KEY" not in os.environ

def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")

if sys.argv[1] == "init":
    private = Ed25519PrivateKey.generate()
    Path("/signer/private.key").write_bytes(
        private.private_bytes(
            serialization.Encoding.Raw,
            serialization.PrivateFormat.Raw,
            serialization.NoEncryption(),
        )
    )
    Path("/receiver/public.key").write_bytes(
        private.public_key().public_bytes(
            serialization.Encoding.Raw,
            serialization.PublicFormat.Raw,
        )
    )
    print("B16D_SYNTHETIC_KEY_INIT=OK")
    sys.exit(0)

private = Ed25519PrivateKey.from_private_bytes(
    Path("/signer/private.key").read_bytes()
)
transport = Path("/signer/transport.key").read_bytes()
now = int(time.time())

evidence = {
    "version": 3,
    "key_id": "b16d-synthetic",
    "object_key": str(uuid.uuid4()),
    "sha256": hashlib.sha256(b"b16d-synthetic").hexdigest(),
    "verdict": "clean",
    "scanned_at": now,
    "engine": "b16d-synthetic",
}

body = {
    "version": 1,
    "timestamp": now,
    "nonce": secrets.token_hex(16),
    "evidence": evidence,
    "signature": private.sign(
        SIGN_DOMAIN + canonical(evidence)
    ).hex(),
}

def envelope(body, key=transport):
    return {
        "body": body,
        "mac": hmac.new(
            key, DOMAIN + canonical(body), hashlib.sha256
        ).hexdigest(),
    }

def send(item):
    request = urllib.request.Request(
        "http://b16d-receiver:8080/evidence",
        data=canonical(item),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code

for attempt in range(40):
    try:
        first = send(envelope(body))
        break
    except (OSError, urllib.error.URLError):
        time.sleep(1)
else:
    raise RuntimeError("RECEIVER_UNREACHABLE")

assert first == 201, f"VALID_STATUS={first}"
print("B16D_NETWORK_ACCEPT=OK")

assert send(envelope(body)) == 409
print("B16D_DURABLE_REPLAY=OK")

assert send(envelope(body, secrets.token_bytes(32))) == 401
print("B16D_WRONG_HMAC_REJECTED=OK")

altered = json.loads(json.dumps(body))
altered["evidence"]["verdict"] = "infected"
assert send(envelope(altered)) == 403
print("B16D_TAMPER_REJECTED=OK")

wrong = json.loads(json.dumps(body))
wrong["nonce"] = secrets.token_hex(16)
wrong["signature"] = "0" * 128
assert send(envelope(wrong)) == 403
print("B16D_FORGED_SIGNATURE_REJECTED=OK")

expired = json.loads(json.dumps(body))
expired["nonce"] = secrets.token_hex(16)
expired["timestamp"] = now - 200
assert send(envelope(expired)) == 403
print("B16D_EXPIRED_MESSAGE_REJECTED=OK")
