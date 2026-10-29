import hashlib
import hmac
import json
import secrets
import urllib.error
import urllib.request
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)

DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"
SIGN_DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"


def canonical(value):
    return json.dumps(
        value, sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


import os
assert not any(
    key.startswith("POSTGRES_")
    for key in os.environ
), "B17D_SIGNER_DB_CREDENTIALS_EXPOSED"
print("B17D_SIGNER_DB_ISOLATION=OK")

fixture = json.loads(Path("/exchange/fixture.json").read_text())

private = Ed25519PrivateKey.from_private_bytes(
    Path("/signer/private.key").read_bytes()
)
transport = Path("/signer/transport.key").read_bytes()

assert len(transport) == 32

evidence = {
    "version": 3,
    "key_id": fixture["key_id"],
    "object_key": fixture["storage_key"],
    "sha256": fixture["sha256"],
    "verdict": "clean",
    "scanned_at": fixture["timestamp"],
    "engine": "b17c2-synthetic",
}

body = {
    "version": 1,
    "timestamp": fixture["timestamp"],
    "nonce": secrets.token_hex(16),
    "evidence": evidence,
    "signature": private.sign(
        SIGN_DOMAIN + canonical(evidence)
    ).hex(),
}


def envelope(value, key=transport):
    return {
        "body": value,
        "mac": hmac.new(
            key,
            DOMAIN + canonical(value),
            hashlib.sha256,
        ).hexdigest(),
    }


def send(value):
    request = urllib.request.Request(
        "http://b17c2-receiver:8080/evidence",
        data=canonical(value),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(
            request, timeout=8
        ) as response:
            return response.status
    except urllib.error.HTTPError as exc:
        return exc.code



# B17D: rechazos a nivel de transporte HTTP.
def raw_request(path, payload, content_type="application/json"):
    request = urllib.request.Request(
        "http://b17c2-receiver:8080" + path,
        data=payload,
        headers={"Content-Type": content_type},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as result:
            return result.status
    except urllib.error.HTTPError as exc:
        return exc.code


assert raw_request("/unknown", b"{}") == 404
print("B17D_UNKNOWN_PATH=OK")

assert raw_request(
    "/evidence", b"{}", "text/plain"
) == 415
print("B17D_MEDIA_TYPE=OK")

assert raw_request(
    "/evidence", b"not-json"
) == 403
print("B17D_INVALID_JSON=OK")

assert raw_request(
    "/evidence", b"x" * 8193
) == 413
print("B17D_OVERSIZED_BODY=OK")

assert raw_request(
    "/evidence", b"[]"
) == 403
print("B17D_INVALID_ENVELOPE=OK")

assert send(envelope(body)) == 201
print("B17C2_HTTP_TO_DJANGO=OK")

assert send(envelope(body)) == 409
print("B17C2_REPLAY_REJECTED=OK")

fresh = json.loads(json.dumps(body))
fresh["nonce"] = secrets.token_hex(16)

assert send(envelope(fresh)) == 403
print("B17D_DUPLICATE_EVIDENCE_REJECTED=OK")


assert send(envelope(
    body, secrets.token_bytes(32)
)) == 403
print("B17C2_WRONG_HMAC_REJECTED=OK")

altered = json.loads(json.dumps(body))
altered["nonce"] = secrets.token_hex(16)
altered["evidence"]["verdict"] = "infected"

assert send(envelope(altered)) == 403
print("B17C2_TAMPER_REJECTED=OK")

forged = json.loads(json.dumps(body))
forged["nonce"] = secrets.token_hex(16)
forged["signature"] = "0" * 128

assert send(envelope(forged)) == 403
print("B17C2_FORGED_SIGNATURE_REJECTED=OK")
