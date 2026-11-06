import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)
from django.test import SimpleTestCase

from .offline_ed25519_b13b import (
    issue_verdict, verify_verdict, public_key_bytes,
)


class B13BEd25519Tests(SimpleTestCase):
    def setUp(self):
        self.private = Ed25519PrivateKey.generate()
        self.public = public_key_bytes(self.private)
        self.now = datetime(2026, 10, 29, tzinfo=timezone.utc)
        self.item = SimpleNamespace(
            storage_key=uuid.uuid4(),
            sha256=hashlib.sha256(b"synthetic").hexdigest(),
            state="quarantined",
        )
        self.payload, self.signature = issue_verdict(
            private_key=self.private,
            attachment=self.item,
            engine="synthetic-scanner",
            now=self.now,
        )

    def verify(self, **changes):
        values = dict(
            payload=self.payload,
            signature=self.signature,
            public_key=self.public,
            attachment=self.item,
            now=self.now,
        )
        values.update(changes)
        return verify_verdict(**values)

    def test_valid(self):
        self.assertTrue(self.verify())

    def test_wrong_public_key(self):
        other = public_key_bytes(Ed25519PrivateKey.generate())
        self.assertFalse(self.verify(public_key=other))

    def test_tampered_signature(self):
        self.assertFalse(self.verify(signature="0" * 128))

    def test_tampered_digest(self):
        self.assertFalse(self.verify(
            payload={**self.payload, "sha256": "0" * 64}
        ))

    def test_wrong_object(self):
        item = SimpleNamespace(
            storage_key=uuid.uuid4(),
            sha256=self.item.sha256,
            state="quarantined",
        )
        self.assertFalse(self.verify(attachment=item))

    def test_wrong_state(self):
        self.item.state = "clean"
        self.assertFalse(self.verify())

    def test_expired(self):
        self.assertFalse(self.verify(
            now=self.now + timedelta(minutes=11)
        ))

    def test_future_timestamp(self):
        self.assertFalse(self.verify(
            now=self.now - timedelta(minutes=2)
        ))

    def test_wrong_domain_version(self):
        self.assertFalse(self.verify(
            payload={**self.payload, "version": 1}
        ))

    def test_infected_not_accepted(self):
        self.assertFalse(self.verify(
            payload={**self.payload, "verdict": "infected"}
        ))

    def test_malformed_public_key(self):
        self.assertFalse(self.verify(public_key=b"short"))

    def test_private_key_required_for_signing(self):
        with self.assertRaises(ValueError):
            issue_verdict(
                private_key=self.public,
                attachment=self.item,
                engine="synthetic-scanner",
                now=self.now,
            )
