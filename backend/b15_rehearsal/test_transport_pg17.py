import hashlib
import hmac
import json
import os
import secrets
import time
import uuid
import unittest

from concurrent.futures import ThreadPoolExecutor

import psycopg
from psycopg.errors import UniqueViolation
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from cryptography.hazmat.primitives import serialization

DB = dict(
    host=os.environ["POSTGRES_HOST"],
    dbname=os.environ["POSTGRES_DB"],
    user=os.environ["POSTGRES_USER"],
    password=os.environ["POSTGRES_PASSWORD"],
)

TRANSPORT_DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"
SIGN_DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"

def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")

def connection():
    return psycopg.connect(**DB)

def issue(key, private, now):
    evidence = {
        "version": 3,
        "key_id": "b15-synthetic",
        "object_key": str(uuid.uuid4()),
        "sha256": hashlib.sha256(b"synthetic").hexdigest(),
        "verdict": "clean",
        "scanned_at": now,
        "engine": "synthetic-b15",
    }
    signature = private.sign(
        SIGN_DOMAIN + canonical(evidence)
    ).hex()
    body = {
        "version": 1,
        "timestamp": now,
        "nonce": secrets.token_hex(16),
        "evidence": evidence,
        "signature": signature,
    }
    mac = hmac.new(
        key, TRANSPORT_DOMAIN + canonical(body),
        hashlib.sha256,
    ).hexdigest()
    return {"body": body, "mac": mac}

def accept(envelope, key, public, now):
    try:
        if type(envelope) is not dict:
            return False
        if set(envelope) != {"body", "mac"}:
            return False

        body = envelope["body"]
        if type(body) is not dict or set(body) != {
            "version", "timestamp", "nonce",
            "evidence", "signature",
        }:
            return False

        if type(body["version"]) is not int or body["version"] != 1:
            return False
        if type(body["timestamp"]) is not int:
            return False
        if not 0 <= now - body["timestamp"] <= 120:
            return False

        nonce = body["nonce"]
        if (
            type(nonce) is not str
            or len(nonce) != 32
            or any(c not in "0123456789abcdef" for c in nonce)
        ):
            return False

        mac = envelope["mac"]
        if type(mac) is not str or len(mac) != 64:
            return False

        expected = hmac.new(
            key, TRANSPORT_DOMAIN + canonical(body),
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(mac, expected):
            return False

        evidence = body["evidence"]
        signature = body["signature"]
        if type(evidence) is not dict or set(evidence) != {
            "version", "key_id", "object_key", "sha256",
            "verdict", "scanned_at", "engine",
        }:
            return False

        if (
            evidence["version"] != 3
            or evidence["key_id"] != "b15-synthetic"
            or evidence["verdict"] != "clean"
            or type(evidence["scanned_at"]) is not int
            or not 0 <= now - evidence["scanned_at"] <= 600
            or type(signature) is not str
            or len(signature) != 128
        ):
            return False

        Ed25519PublicKey.from_public_bytes(public).verify(
            bytes.fromhex(signature),
            SIGN_DOMAIN + canonical(evidence),
        )

        # La unicidad la aplica PostgreSQL, no la memoria.
        # Verificación y registro forman una única aceptación.
        with connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO b15_seen (nonce) VALUES (%s)",
                    (nonce,),
                )
        return True

    except (
        ValueError, TypeError, KeyError, InvalidSignature,
        UniqueViolation, psycopg.Error, OverflowError,
    ):
        return False


class B15Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with connection() as conn:
            conn.execute(
                "CREATE TABLE IF NOT EXISTS b15_seen "
                "(nonce varchar(32) PRIMARY KEY)"
            )

    def setUp(self):
        with connection() as conn:
            conn.execute("DELETE FROM b15_seen")

        self.now = int(time.time())
        self.key = secrets.token_bytes(32)
        self.private = Ed25519PrivateKey.generate()
        self.public = self.private.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        self.message = issue(
            self.key, self.private, self.now
        )

    def verify(self, message=None, key=None, public=None, now=None):
        return accept(
            self.message if message is None else message,
            self.key if key is None else key,
            self.public if public is None else public,
            self.now if now is None else now,
        )

    def test_valid(self):
        self.assertTrue(self.verify())

    def test_replay_after_connection_reopen(self):
        self.assertTrue(self.verify())
        self.assertFalse(self.verify())

    def test_concurrent_replay(self):
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(
                lambda _: self.verify(), range(4)
            ))
        self.assertEqual(results.count(True), 1)
        self.assertEqual(results.count(False), 3)

    def test_wrong_transport_key(self):
        self.assertFalse(
            self.verify(key=secrets.token_bytes(32))
        )

    def test_wrong_ed25519_public_key(self):
        other = Ed25519PrivateKey.generate()
        wrong = other.public_key().public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw,
        )
        self.assertFalse(self.verify(public=wrong))

    def test_expired_transport(self):
        self.assertFalse(self.verify(now=self.now + 121))

    def test_modified_evidence(self):
        altered = json.loads(json.dumps(self.message))
        altered["body"]["evidence"]["verdict"] = "infected"
        self.assertFalse(self.verify(message=altered))

    def test_forged_transport_mac(self):
        altered = json.loads(json.dumps(self.message))
        altered["mac"] = "0" * 64
        self.assertFalse(self.verify(message=altered))

    def test_forged_ed25519_signature(self):
        altered = json.loads(json.dumps(self.message))
        altered["body"]["signature"] = "0" * 128
        altered["mac"] = hmac.new(
            self.key,
            TRANSPORT_DOMAIN + canonical(altered["body"]),
            hashlib.sha256,
        ).hexdigest()
        self.assertFalse(self.verify(message=altered))

    def test_rejection_not_recorded(self):
        self.assertFalse(
            self.verify(key=secrets.token_bytes(32))
        )
        with connection() as conn:
            count = conn.execute(
                "SELECT count(*) FROM b15_seen"
            ).fetchone()[0]
        self.assertEqual(count, 0)



    def test_future_message_rejected(self):
        self.assertFalse(self.verify(now=self.now - 1))

    def test_invalid_nonce_rejected(self):
        altered = json.loads(json.dumps(self.message))
        altered["body"]["nonce"] = "invalid"
        altered["mac"] = hmac.new(
            self.key,
            TRANSPORT_DOMAIN + canonical(altered["body"]),
            hashlib.sha256,
        ).hexdigest()
        self.assertFalse(self.verify(message=altered))


if __name__ == "__main__":
    result = unittest.TextTestRunner(
        verbosity=1
    ).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(B15Tests)
    )
    print(
        "B15CD_DURABLE_REPLAY="
        + ("OK" if result.wasSuccessful() else "FAIL")
    )
    raise SystemExit(0 if result.wasSuccessful() else 1)
