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
from .offline_ed25519_b13b import (
    issue_verdict, public_key_bytes,
)
from .offline_key_registry_b13d import (
    TrustedPublicKey,
    resolve_public_key,
    persist_keyed_evidence_offline,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B13DKeyRegistryPG17Tests(TransactionTestCase):

    def setUp(self):
        self.now = datetime.now(timezone.utc)
        self.old_private = Ed25519PrivateKey.generate()
        self.new_private = Ed25519PrivateKey.generate()

        self.registry = {
            "scanner-2026-a": self.entry(
                "scanner-2026-a", self.old_private
            ),
            "scanner-2026-b": self.entry(
                "scanner-2026-b", self.new_private
            ),
        }

        ws = Workspace.objects.create(name="B13D synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B13D",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        content = b"synthetic-b13d"
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            state="quarantined",
        )
        self.sign(self.old_private)

    def entry(self, key_id, private, revoked=False):
        return TrustedPublicKey(
            key_id=key_id,
            public_key=public_key_bytes(private),
            valid_from=self.now - timedelta(days=1),
            valid_until=self.now + timedelta(days=1),
            revoked=revoked,
        )

    def sign(self, private):
        self.payload, self.signature = issue_verdict(
            private_key=private,
            attachment=self.item,
            engine="synthetic-b13d",
            now=self.now,
        )

    def fingerprint(self):
        return tuple(getattr(self.item, field) for field in (
            "storage_key", "sha256", "byte_size",
            "state", "display_name", "content_type",
        ))

    def persist(self, key_id="scanner-2026-a", **changes):
        args = {
            "registry": self.registry,
            "key_id": key_id,
            "attachment_id": self.item.pk,
            "payload": self.payload,
            "signature": self.signature,
            "expected_fingerprint": self.fingerprint(),
            "now": self.now,
        }
        args.update(changes)
        return persist_keyed_evidence_offline(**args)

    def test_trusted_key_accepted_without_release(self):
        saved = self.persist()
        self.assertEqual(len(saved.signature), 128)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertFalse(may_download_attachment(
            attachment=self.item, membership=None
        ))

    def test_rotated_key_accepted(self):
        self.sign(self.new_private)
        self.persist(key_id="scanner-2026-b")
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_unknown_key_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(key_id="scanner-unknown")

    def test_revoked_key_rejected(self):
        self.registry["scanner-2026-a"] = self.entry(
            "scanner-2026-a", self.old_private, revoked=True
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_wrong_key_selection_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(key_id="scanner-2026-b")

    def test_expired_key_rejected(self):
        old = self.registry["scanner-2026-a"]
        self.registry["scanner-2026-a"] = TrustedPublicKey(
            old.key_id, old.public_key,
            self.now - timedelta(days=3),
            self.now - timedelta(days=1),
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_not_yet_valid_key_rejected(self):
        old = self.registry["scanner-2026-a"]
        self.registry["scanner-2026-a"] = TrustedPublicKey(
            old.key_id, old.public_key,
            self.now + timedelta(days=1),
            self.now + timedelta(days=2),
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_malformed_key_id_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(key_id="../private")

    def test_malformed_public_key_rejected(self):
        old = self.registry["scanner-2026-a"]
        self.registry["scanner-2026-a"] = TrustedPublicKey(
            old.key_id, b"invalid",
            old.valid_from, old.valid_until,
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_duplicate_rejected(self):
        self.persist()
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_production_blocked(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.persist()

    def test_revocation_preserves_previous_evidence(self):
        self.persist()
        evidence_id = AttachmentScanEvidence.objects.get().pk
        self.registry["scanner-2026-a"] = self.entry(
            "scanner-2026-a", self.old_private, revoked=True
        )
        self.assertTrue(
            AttachmentScanEvidence.objects.filter(
                pk=evidence_id
            ).exists()
        )
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_registry_contains_only_public_bytes(self):
        for entry in self.registry.values():
            self.assertEqual(type(entry.public_key), bytes)
            self.assertEqual(len(entry.public_key), 32)

    def test_naive_time_rejected(self):
        with self.assertRaises(PermissionDenied):
            resolve_public_key(
                registry=self.registry,
                key_id="scanner-2026-a",
                now=datetime(2026, 10, 29),
            )
