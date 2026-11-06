import hashlib
from datetime import date, datetime, timedelta, timezone

from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)
from django.core.exceptions import PermissionDenied
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from reminders.attachment_gate import may_download_attachment
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_ed25519_b13b import public_key_bytes
from .offline_key_registry_b13d import TrustedPublicKey
from .offline_keyed_v3_b13e import (
    issue_keyed_verdict,
    verify_keyed_verdict,
    persist_keyed_v3_offline,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B13EKeyedEvidencePG17Tests(TransactionTestCase):
    def setUp(self):
        self.now = datetime.now(timezone.utc)
        self.private = Ed25519PrivateKey.generate()
        self.other = Ed25519PrivateKey.generate()
        ws = Workspace.objects.create(name="B13E synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B13E",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        content = b"b13e-synthetic"
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            state="quarantined",
        )
        self.registry = {
            "scanner-a": TrustedPublicKey(
                "scanner-a",
                public_key_bytes(self.private),
                self.now - timedelta(days=1),
                self.now + timedelta(days=1),
            ),
            "scanner-b": TrustedPublicKey(
                "scanner-b",
                public_key_bytes(self.other),
                self.now - timedelta(days=1),
                self.now + timedelta(days=1),
            ),
        }
        self.payload, self.signature = issue_keyed_verdict(
            private_key=self.private,
            key_id="scanner-a",
            attachment=self.item,
            engine="synthetic-b13e",
            now=self.now,
        )

    def fingerprint(self):
        fields = (
            "storage_key", "sha256", "byte_size",
            "state", "display_name", "content_type",
        )
        return tuple(getattr(self.item, f) for f in fields)

    def persist(self, **changes):
        args = dict(
            attachment_id=self.item.pk,
            payload=self.payload,
            signature=self.signature,
            registry=self.registry,
            expected_fingerprint=self.fingerprint(),
            now=self.now,
        )
        args.update(changes)
        return persist_keyed_v3_offline(**args)

    def test_signed_key_id_is_audited(self):
        saved = self.persist()
        saved.refresh_from_db()
        self.assertEqual(saved.payload["version"], 3)
        self.assertEqual(saved.payload["key_id"], "scanner-a")
        self.assertEqual(len(saved.signature), 128)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertFalse(may_download_attachment(
            attachment=self.item, membership=None
        ))

    def test_key_id_tampering_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(payload={
                **self.payload, "key_id": "scanner-b"
            })

    def test_unknown_key_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(payload={
                **self.payload, "key_id": "unknown"
            })

    def test_revoked_key_rejected(self):
        old = self.registry["scanner-a"]
        self.registry["scanner-a"] = TrustedPublicKey(
            old.key_id, old.public_key,
            old.valid_from, old.valid_until, revoked=True,
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_wrong_signer_rejected(self):
        forged, signature = issue_keyed_verdict(
            private_key=self.other,
            key_id="scanner-a",
            attachment=self.item,
            engine="synthetic-b13e",
            now=self.now,
        )
        with self.assertRaises(PermissionDenied):
            self.persist(payload=forged, signature=signature)

    def test_duplicate_rejected(self):
        self.persist()
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_expired_evidence_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(now=self.now + timedelta(minutes=12))

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.persist()

    def test_version_two_rejected_by_v3(self):
        self.assertFalse(verify_keyed_verdict(
            payload={**self.payload, "version": 2},
            signature=self.signature,
            registry=self.registry,
            attachment=self.item,
            now=self.now,
        ))

    def test_signed_payload_modified_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(payload={
                **self.payload, "engine": "different"
            })
