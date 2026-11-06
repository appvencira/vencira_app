import hashlib
from datetime import date, datetime, timezone
from unittest.mock import patch

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
from .offline_ed25519_persistence_b13c import (
    persist_ed25519_evidence_offline,
)


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B13CEd25519PG17Tests(TransactionTestCase):

    def setUp(self):
        ws = Workspace.objects.create(name="B13C synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B13C",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        content = b"synthetic-b13c-document"
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(content),
            sha256=hashlib.sha256(content).hexdigest(),
            state=RenewalAttachment.State.QUARANTINED,
        )
        self.private = Ed25519PrivateKey.generate()
        self.public = public_key_bytes(self.private)
        self.now = datetime.now(timezone.utc)
        self.payload, self.signature = issue_verdict(
            private_key=self.private,
            attachment=self.item,
            engine="synthetic-b13c",
            now=self.now,
        )

    def fingerprint(self):
        return tuple(getattr(self.item, field) for field in (
            "storage_key", "sha256", "byte_size",
            "state", "display_name", "content_type",
        ))

    def persist(self, **changes):
        args = {
            "attachment_id": self.item.pk,
            "payload": self.payload,
            "signature": self.signature,
            "public_key": self.public,
            "expected_fingerprint": self.fingerprint(),
            "now": self.now,
        }
        args.update(changes)
        return persist_ed25519_evidence_offline(**args)

    def test_valid_signature_persisted_without_release(self):
        saved = self.persist()
        self.assertEqual(len(saved.signature), 128)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertFalse(may_download_attachment(
            attachment=self.item,
            membership=None,
        ))

    def test_wrong_public_key_rejected(self):
        wrong = public_key_bytes(Ed25519PrivateKey.generate())
        with self.assertRaises(PermissionDenied):
            self.persist(public_key=wrong)
        self.assertFalse(AttachmentScanEvidence.objects.exists())

    def test_forged_signature_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(signature="0" * 128)
        self.assertFalse(AttachmentScanEvidence.objects.exists())

    def test_modified_metadata_rejected(self):
        original = self.fingerprint()
        self.item.display_name = "modified.pdf"
        self.item.save(update_fields=["display_name"])
        with self.assertRaises(PermissionDenied):
            self.persist(expected_fingerprint=original)

    def test_duplicate_rejected(self):
        self.persist()
        with self.assertRaises(PermissionDenied):
            self.persist()
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)

    def test_infected_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(payload={
                **self.payload, "verdict": "infected"
            })

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.persist()
        self.assertFalse(AttachmentScanEvidence.objects.exists())

    def test_hmac_field_capacity_preserved(self):
        field = AttachmentScanEvidence._meta.get_field("signature")
        self.assertEqual(field.max_length, 128)

    def test_no_signer_invoked_by_receiver(self):
        with patch(
            "renewal_attachments.offline_ed25519_b13b.issue_verdict",
            side_effect=AssertionError("Signer unexpectedly invoked"),
        ):
            self.persist()
