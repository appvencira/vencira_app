"""Synthetic-only attestation tests; no scanner, upload or download."""
import hashlib
import hmac
import json
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

from django.test import SimpleTestCase

from .attachment_scan_contract import verify_scan_verdict


class AttachmentScanContractTests(SimpleTestCase):
    def setUp(self):
        self.key = b"k" * 32
        self.object_id = uuid.uuid4()
        self.attachment = SimpleNamespace(storage_key=self.object_id, sha256="a" * 64)
        self.time = datetime(2026, 10, 27, tzinfo=timezone.utc)
        self.payload = {
            "object_key": self.object_id.hex, "sha256": "a" * 64,
            "verdict": "clean", "scanned_at": int(self.time.timestamp()),
            "engine": "synthetic-test-only",
        }

    def sign(self, payload):
        raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
        return hmac.new(self.key, raw, hashlib.sha256).hexdigest()

    def check(self, payload, signature=None, key=None):
        return verify_scan_verdict(
            payload=payload, signature=signature if signature is not None else self.sign(payload),
            verification_key=key if key is not None else self.key,
            attachment=self.attachment, now=self.time,
        )

    def test_valid_synthetic_signature_verifies_but_does_not_enable_download(self):
        self.assertTrue(self.check(self.payload))

    def test_forgery_foreign_object_and_modified_digest_rejected(self):
        cases = [
            ({**self.payload, "object_key": uuid.uuid4().hex}, self.sign(self.payload)),
            ({**self.payload, "sha256": "b" * 64}, self.sign(self.payload)),
            (self.payload, "0" * 64),
        ]
        for payload, signature in cases:
            with self.subTest(payload=payload):
                self.assertFalse(self.check(payload, signature=signature))

    def test_stale_future_and_nonclean_verdict_rejected(self):
        for changes in (
            {"scanned_at": self.payload["scanned_at"] - 601},
            {"scanned_at": self.payload["scanned_at"] + 31},
            {"verdict": "infected"},
            {"verdict": "error"},
            {"engine": ""},
        ):
            with self.subTest(changes=changes):
                changed = {**self.payload, **changes}
                self.assertFalse(self.check(changed))

    def test_bad_key_and_extra_fields_rejected(self):
        self.assertFalse(self.check(self.payload, key=b"x" * 32))
        altered = {**self.payload, "unexpected": "present"}
        self.assertFalse(self.check(altered))
