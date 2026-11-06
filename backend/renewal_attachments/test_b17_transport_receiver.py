import json
from datetime import timedelta

from django.core.exceptions import PermissionDenied
from django.db import IntegrityError, connection
from django.test import override_settings

from .offline_key_registry_b13d import TrustedPublicKey
from .offline_ed25519_b13b import public_key_bytes
from .test_b15f_atomic_receiver import B15FAtomicReceiverTests
from .offline_transport_receiver_b17 import receive_envelope_offline
from .models import AttachmentScanEvidence


class B17TransportReceiverTests(B15FAtomicReceiverTests):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        with connection.cursor() as cursor:
            cursor.execute(
                "CREATE TABLE IF NOT EXISTS b17_replay "
                "(nonce varchar(32) PRIMARY KEY)"
            )

    @classmethod
    def tearDownClass(cls):
        try:
            with connection.cursor() as cursor:
                cursor.execute("DROP TABLE IF EXISTS b17_replay")
        finally:
            super().tearDownClass()

    def setUp(self):
        super().setUp()
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM b17_replay")

    def receive(
        self, *, body=None, mac=None, registry=None,
        fail_after_evidence=False,
    ):
        return receive_envelope_offline(
            envelope={
                "body": self.body if body is None else body,
                "mac": self.mac if mac is None else mac,
            },
            transport_key=self.transport_key,
            registry=self.registry if registry is None else registry,
            attachment_id=self.item.pk,
            expected_fingerprint=self.fingerprint,
            now=self.now,
            fail_after_evidence=fail_after_evidence,
        )

    def replay_count(self):
        with connection.cursor() as cursor:
            cursor.execute("SELECT count(*) FROM b17_replay")
            return cursor.fetchone()[0]

    def test_production_fail_closed(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.receive()
        self.assertEqual(self.replay_count(), 0)

    def test_missing_flag_fail_closed(self):
        with override_settings(
            VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=False
        ):
            with self.assertRaises(PermissionDenied):
                self.receive()
        self.assertEqual(self.replay_count(), 0)

    def test_rejected_does_not_consume_nonce(self):
        with self.assertRaises(PermissionDenied):
            self.receive(mac="0" * 64)
        self.assertEqual(self.replay_count(), 0)
        self.receive()
        self.assertEqual(self.replay_count(), 1)

    def test_replay_after_rollback(self):
        with self.assertRaises(RuntimeError):
            self.receive(fail_after_evidence=True)
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)
        self.receive()
        self.assertEqual(self.replay_count(), 1)

    def test_future_timestamp_rejected(self):
        altered = json.loads(json.dumps(self.body))
        altered["timestamp"] = int(
            (self.now + timedelta(seconds=10)).timestamp()
        )
        with self.assertRaises(PermissionDenied):
            self.receive(body=altered, mac=self.sign_transport(altered))
        self.assertEqual(self.replay_count(), 0)

    def test_unknown_signer_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.receive(registry={})
        self.assertEqual(self.replay_count(), 0)

    def test_invalid_transport_key_rejected(self):
        with self.assertRaises(PermissionDenied):
            receive_envelope_offline(
                envelope={"body": self.body, "mac": self.mac},
                transport_key=b"invalid",
                registry=self.registry,
                attachment_id=self.item.pk,
                expected_fingerprint=self.fingerprint,
                now=self.now,
            )
        self.assertEqual(self.replay_count(), 0)
