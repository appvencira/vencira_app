import hashlib
import hmac
import json
import os
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

import psycopg
from psycopg.errors import UniqueViolation
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"
SIGN_DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"

assert os.geteuid() == 65532
assert not Path("/run/keys/private.key").exists()
assert "DJANGO_SECRET_KEY" not in os.environ

key = Path("/run/keys/transport.key").read_bytes()
public = Path("/run/keys/public.key").read_bytes()
assert len(key) == 32 and len(public) == 32

def canonical(x):
    return json.dumps(
        x, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")

def connect():
    return psycopg.connect(
        host=os.environ["POSTGRES_HOST"],
        dbname="b16d", user="b16d",
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=5,
    )

with connect() as db:
    db.execute(
        "CREATE TABLE IF NOT EXISTS received "
        "(nonce varchar(32) PRIMARY KEY)"
    )

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def respond(self, status):
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_POST(self):
        if urlsplit(self.path).path != "/evidence":
            return self.respond(404)
        try:
            length = int(self.headers.get("Content-Length", "-1"))
            if not 0 < length <= 8192:
                return self.respond(413)

            envelope = json.loads(self.rfile.read(length))
            if type(envelope) is not dict or set(envelope) != {"body", "mac"}:
                return self.respond(403)

            body, mac = envelope["body"], envelope["mac"]
            if type(body) is not dict or set(body) != {
                "version", "timestamp", "nonce",
                "evidence", "signature",
            }:
                return self.respond(403)

            nonce = body["nonce"]
            now = int(time.time())
            if (
                type(body["version"]) is not int
                or body["version"] != 1
                or type(body["timestamp"]) is not int
                or not 0 <= now - body["timestamp"] <= 120
                or type(nonce) is not str
                or not re.fullmatch(r"[0-9a-f]{32}", nonce)
                or type(mac) is not str
                or not re.fullmatch(r"[0-9a-f]{64}", mac)
            ):
                return self.respond(403)

            expected = hmac.new(
                key, DOMAIN + canonical(body), hashlib.sha256
            ).hexdigest()
            if not hmac.compare_digest(expected, mac):
                return self.respond(401)

            evidence = body["evidence"]
            signature = body["signature"]
            if type(evidence) is not dict or set(evidence) != {
                "version", "key_id", "object_key",
                "sha256", "verdict", "scanned_at", "engine",
            }:
                return self.respond(403)
            if (
                type(evidence["version"]) is not int
                or evidence["version"] != 3
                or evidence["key_id"] != "b16d-synthetic"
                or evidence["verdict"] != "clean"
                or type(evidence["scanned_at"]) is not int
                or not -30 <= now - evidence["scanned_at"] <= 600
                or type(signature) is not str
                or not re.fullmatch(r"[0-9a-f]{128}", signature)
            ):
                return self.respond(403)

            Ed25519PublicKey.from_public_bytes(public).verify(
                bytes.fromhex(signature),
                SIGN_DOMAIN + canonical(evidence),
            )

            with connect() as db:
                db.execute(
                    "INSERT INTO received (nonce) VALUES (%s)",
                    (nonce,),
                )
            return self.respond(201)

        except UniqueViolation:
            return self.respond(409)
        except (ValueError, TypeError, KeyError, UnicodeError):
            return self.respond(403)
        except Exception as exc:
            if exc.__class__.__name__ == "InvalidSignature":
                return self.respond(403)
            return self.respond(503)

print("B16D_RECEIVER_READY=OK", flush=True)
ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
