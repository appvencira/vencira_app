"""Metadata tests use only test databases, never store file contents."""
from datetime import date

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase

from .models import Renewal, RenewalAttachment, Workspace


class AttachmentMetadataTests(TestCase):
    def setUp(self):
        self.owner = get_user_model().objects.create_user(username="attachment_demo")
        self.workspace = Workspace.objects.create(name="Workspace demo")
        self.renewal = Renewal.objects.create(
            workspace=self.workspace,
            customer_reference="DEMO-ATTACH",
            full_name="Persona ficticia",
            expires_on=date(2027, 6, 1),
        )

    def make_attachment(self):
        return RenewalAttachment.objects.create(
            renewal=self.renewal, uploaded_by=self.owner,
            display_name="ejemplo.pdf", content_type="application/pdf",
            byte_size=100, sha256="a" * 64,
        )

    def test_quarantine_by_default_and_opaque_key(self):
        item = self.make_attachment()
        self.assertEqual(item.state, RenewalAttachment.State.QUARANTINED)
        self.assertNotIn("ejemplo", str(item.storage_key))
        self.assertEqual(self.renewal.attachments.count(), 1)

    def test_duplicate_storage_key_rejected(self):
        first = self.make_attachment()
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                RenewalAttachment.objects.create(
                    renewal=self.renewal, uploaded_by=self.owner,
                    display_name="otro.pdf", content_type="application/pdf",
                    byte_size=120, sha256="b" * 64, storage_key=first.storage_key,
                )

    def test_zero_size_rejected_at_db(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                RenewalAttachment.objects.create(
                    renewal=self.renewal, uploaded_by=self.owner,
                    display_name="vacio.pdf", content_type="application/pdf",
                    byte_size=0, sha256="c" * 64,
                )
