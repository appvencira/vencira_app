import hashlib

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .offline_db_envelope_b08 import (
    DatabaseEnvelopeError,
    MAX_DUMP,
    seal_database_dump,
    open_database_dump,
)


class B08AEncryptedDatabaseTests(SimpleTestCase):
    def setUp(self):
        self.raw = b"PGDMP B08A SYNTHETIC DUMP"
        self.key = Fernet.generate_key()
        self.expected = hashlib.sha256(self.raw).hexdigest()
        self.envelope = seal_database_dump(
            dump_bytes=self.raw,
            key=self.key,
            key_id="b08-key-v1",
            snapshot_id="b08-snapshot",
        )

    def restore(self, **changes):
        args = {
            "envelope": self.envelope,
            "key": self.key,
            "expected_key_id": "b08-key-v1",
            "expected_snapshot_id": "b08-snapshot",
            "expected_sha256": self.expected,
        }
        args.update(changes)
        return open_database_dump(**args)

    def test_round_trip(self):
        self.assertEqual(self.restore(), self.raw)

    def test_plaintext_not_in_ciphertext(self):
        self.assertNotIn(self.raw, self.envelope)

    def test_wrong_key_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(key=Fernet.generate_key())

    def test_wrong_snapshot_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(expected_snapshot_id="different")

    def test_wrong_key_version_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(expected_key_id="b08-key-v2")

    def test_wrong_external_digest_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(expected_sha256="0" * 64)

    def test_modified_ciphertext_rejected(self):
        damaged = bytearray(self.envelope)
        damaged[len(damaged) // 2] ^= 1
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(envelope=bytes(damaged))

    def test_empty_dump_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            seal_database_dump(
                dump_bytes=b"",
                key=self.key,
                key_id="b08-key-v1",
                snapshot_id="b08-snapshot",
            )

    def test_oversized_dump_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            seal_database_dump(
                dump_bytes=b"x" * (MAX_DUMP + 1),
                key=self.key,
                key_id="b08-key-v1",
                snapshot_id="b08-snapshot",
            )

    def test_invalid_key_version_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(expected_key_id="../../key")

    def test_malformed_envelope_rejected(self):
        with self.assertRaises(DatabaseEnvelopeError):
            self.restore(envelope=b"not-an-envelope")

    def test_deterministic_digest(self):
        restored = self.restore()
        self.assertEqual(
            hashlib.sha256(restored).hexdigest(),
            self.expected,
        )
