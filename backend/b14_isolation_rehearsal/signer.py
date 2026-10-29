"""B14A: firmante sintético, sin ClamAV ni claves reales."""
import hashlib
import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)

assert not any(k.startswith("POSTGRES_") for k in os.environ)
assert "DJANGO_SECRET_KEY" not in os.environ

private = Ed25519PrivateKey.generate()
payload = {
    "version": 3,
    "key_id": "b14a-synthetic",
    "object_key": str(uuid.uuid4()),
    "sha256": hashlib.sha256(b"synthetic-b14a").hexdigest(),
    "verdict": "clean",
    "scanned_at": int(datetime.now(timezone.utc).timestamp()),
    "engine": "b14a-synthetic-only",
}

canonical = json.dumps(
    payload, sort_keys=True,
    separators=(",", ":"), ensure_ascii=True,
).encode("ascii")

signature = private.sign(
    b"VENCIRA-SCAN-ED25519-V3\x00" + canonical
).hex()

public = private.public_key().public_bytes(
    encoding=serialization.Encoding.Raw,
    format=serialization.PublicFormat.Raw,
)

Path("/exchange/evidence.json").write_text(json.dumps({
    "payload": payload, "signature": signature
}))
Path("/exchange/public.hex").write_text(public.hex())

# La clave privada solo existe durante este proceso.
print("B14A_SIGNER=OK")
