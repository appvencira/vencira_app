import hashlib
import hmac
import json
import secrets
from datetime import date, datetime, timedelta, timezone

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from django.core.exceptions import PermissionDenied
from django.db import connection, transaction
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_key_registry_b13d import TrustedPublicKey
from .offline_ed25519_b13b import public_key_bytes
from .offline_write_barrier_b06b import advisory_barrier
from .offline_keyed_v3_b13e import (
    issue_keyed_verdict,
    verify_keyed_verdict,
)

DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"


def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B15FAtomicReceiverTests(TransactionTestCase):

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        with connection.cursor() as cursor:
            cursor.execute(
                "CREATE TABLE IF NOT EXISTS b15f_replay ("
                "nonce varchar(32) PRIMARY KEY)"
            )

    @classmethod
    def tearDownClass(cls):
        try:
            with connection.cursor() as cursor:
                cursor.execute("DROP TABLE IF EXISTS b15f_replay")
        finally:
            super().tearDownClass()

    def setUp(self):
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM b15f_replay")

        self.now = datetime.now(timezone.utc)
        self.private = Ed25519PrivateKey.generate()
        self.transport_key = secrets.token_bytes(32)

        ws = Workspace.objects.create(name="B15F synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B15F",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=32,
            sha256=hashlib.sha256(b"synthetic").hexdigest(),
            state="quarantined",
        )

        self.fingerprint = tuple(
            getattr(self.item, field)
            for field in (
                "storage_key", "sha256", "byte_size",
                "state", "display_name", "content_type",
            )
        )

        self.registry = {
            "b15f-synthetic": TrustedPublicKey(
                "b15f-synthetic",
                public_key_bytes(self.private),
                self.now - timedelta(minutes=1),
                self.now + timedelta(minutes=10),
            )
        }

        payload, signature = issue_keyed_verdict(
            private_key=self.private,
            key_id="b15f-synthetic",
            attachment=self.item,
            engine="synthetic-b15f",
            now=self.now,
        )

        self.body = {
            "version": 1,
            "timestamp": int(self.now.timestamp()),
            "nonce": secrets.token_hex(16),
            "evidence": payload,
            "signature": signature,
        }
        self.mac = self.sign_transport(self.body)

    def sign_transport(self, body):
        return hmac.new(
            self.transport_key,
            DOMAIN + canonical(body),
            hashlib.sha256,
        ).hexdigest()

    def receive(self, *, body=None, mac=None, registry=None,
                fail_after_evidence=False):
        body = self.body if body is None else body
        mac = self.mac if mac is None else mac
        registry = self.registry if registry is None else registry

        if type(body) is not dict or set(body) != {
            "version", "timestamp", "nonce", "evidence", "signature"
        }:
            raise PermissionDenied("INVALID_ENVELOPE")

        nonce = body["nonce"]
        if (
            type(body["version"]) is not int
            or body["version"] != 1
            or type(body["timestamp"]) is not int
            or not 0 <= int(self.now.timestamp()) - body["timestamp"] <= 120
            or type(nonce) is not str
            or len(nonce) != 32
            or any(c not in "0123456789abcdef" for c in nonce)
            or type(mac) is not str
            or len(mac) != 64
        ):
            raise PermissionDenied("INVALID_TRANSPORT")

        expected = self.sign_transport(body)
        if not hmac.compare_digest(mac, expected):
            raise PermissionDenied("BAD_MAC")

        # B06B requiere autocommit y ausencia de transacción
        # al adquirir el bloqueo cooperativo.
        with advisory_barrier(capture=False):
            with transaction.atomic():
                with connection.cursor() as cursor:
                    cursor.execute(
                        "INSERT INTO b15f_replay (nonce) VALUES (%s)",
                        [nonce],
                    )

                attachment = (
                    RenewalAttachment.objects
                    .select_for_update()
                    .get(pk=self.item.pk)
                )

                fields = (
                    "storage_key", "sha256", "byte_size",
                    "state", "display_name", "content_type",
                )
                current = tuple(
                    getattr(attachment, field)
                    for field in fields
                )

                if current != self.fingerprint:
                    raise PermissionDenied("B15F_METADATA_CHANGED")

                if AttachmentScanEvidence.objects.filter(
                    attachment=attachment
                ).exists():
                    raise PermissionDenied("B15F_DUPLICATE_EVIDENCE")

                if not verify_keyed_verdict(
                    payload=body["evidence"],
                    signature=body["signature"],
                    registry=registry,
                    attachment=attachment,
                    now=self.now,
                ):
                    raise PermissionDenied("B15F_INVALID_EVIDENCE")

                evidence = AttachmentScanEvidence.objects.create(
                    attachment=attachment,
                    payload=body["evidence"],
                    signature=body["signature"],
                )

                if fail_after_evidence:
                    raise RuntimeError(
                        "SIMULATED_TRANSACTION_FAILURE"
                    )

                return evidence

    def replay_count(self):
        with connection.cursor() as cursor:
            cursor.execute("SELECT count(*) FROM b15f_replay")
            return cursor.fetchone()[0]

    def test_valid_atomic_acceptance(self):
        self.receive()
        self.assertEqual(self.replay_count(), 1)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")

    def test_duplicate_rejected(self):
        from django.db import IntegrityError
        self.receive()
        with self.assertRaises(IntegrityError):
            self.receive()
        self.assertEqual(self.replay_count(), 1)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_invalid_mac_not_consumed(self):
        with self.assertRaises(PermissionDenied):
            self.receive(mac="0" * 64)
        self.assertEqual(self.replay_count(), 0)

    def test_revoked_key_not_consumed(self):
        revoked = {
            "b15f-synthetic": TrustedPublicKey(
                "b15f-synthetic",
                public_key_bytes(self.private),
                self.now - timedelta(minutes=1),
                self.now + timedelta(minutes=10),
                revoked=True,
            )
        }
        with self.assertRaises(PermissionDenied):
            self.receive(registry=revoked)
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)

    def test_expired_key_not_consumed(self):
        expired = {
            "b15f-synthetic": TrustedPublicKey(
                "b15f-synthetic",
                public_key_bytes(self.private),
                self.now - timedelta(minutes=10),
                self.now - timedelta(minutes=1),
            )
        }
        with self.assertRaises(PermissionDenied):
            self.receive(registry=expired)
        self.assertEqual(self.replay_count(), 0)

    def test_transaction_rollback(self):
        with self.assertRaises(RuntimeError):
            self.receive(fail_after_evidence=True)
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)

        self.receive()
        self.assertEqual(self.replay_count(), 1)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_modified_evidence_rejected(self):
        altered = json.loads(json.dumps(self.body))
        altered["evidence"]["verdict"] = "infected"
        with self.assertRaises(PermissionDenied):
            self.receive(body=altered, mac=self.sign_transport(altered))
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 0)

    def test_wrong_signer_rejected(self):
        wrong = Ed25519PrivateKey.generate()
        altered = json.loads(json.dumps(self.body))
        from .offline_keyed_v3_b13e import DOMAIN as SIGN_DOMAIN
        altered["signature"] = wrong.sign(
            SIGN_DOMAIN + canonical(altered["evidence"])
        ).hex()
        with self.assertRaises(PermissionDenied):
            self.receive(body=altered, mac=self.sign_transport(altered))
        self.assertEqual(self.replay_count(), 0)
