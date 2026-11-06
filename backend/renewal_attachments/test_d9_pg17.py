"""D9: reconciliación sintética en PostgreSQL 17."""
import hashlib
import tempfile
import uuid
from datetime import date
from pathlib import Path

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.attachment_private_store import (
    PrivateQuarantineStore,
)
from reminders.models import (
    Renewal, Workspace, WorkspaceMember,
)
from .models import RenewalAttachment
from .offline_intake import stage_authorized_attachment
from .offline_intake_journal import IntakeJournal
from .offline_reconciliation_d9 import inspect_reconciliation_d9


PDF = b"%PDF-1.4\nD9 synthetic test\n%%EOF"


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D9PostgresTests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")

        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

        root = Path(self.temp.name)
        self.private = root / "private"
        self.journal_root = root / "journal"
        self.private.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)

        self.store = PrivateQuarantineStore(
            self.private, Fernet.generate_key()
        )
        self.journal = IntakeJournal(self.journal_root)

        user = get_user_model().objects.create_user(
            username="d9_synthetic_owner"
        )
        workspace = Workspace.objects.create(
            name="D9 synthetic"
        )
        self.member = WorkspaceMember.objects.create(
            workspace=workspace,
            user=user,
            role=WorkspaceMember.Role.OWNER,
        )
        self.renewal = Renewal.objects.create(
            workspace=workspace,
            full_name="Synthetic",
            customer_reference="D9-SYNTHETIC",
            expires_on=date(2027, 12, 1),
        )

    def intake(self):
        return stage_authorized_attachment(
            member=self.member,
            renewal_id=self.renewal.pk,
            store=self.store,
            journal=self.journal,
            filename="synthetic.pdf",
            content_type="application/pdf",
            content=PDF,
        )

    def audit(self):
        return inspect_reconciliation_d9(
            journal=self.journal,
            store=self.store,
        )

    def test_consistent_without_release(self):
        item = self.intake()
        before = (self.private / item.storage_key.hex).read_bytes()

        result = self.audit()

        self.assertEqual(result["consistent"], 1)
        self.assertFalse(result["requires_review"])
        self.assertFalse(result["release_authorized"])
        self.assertEqual(
            (self.private / item.storage_key.hex).read_bytes(),
            before,
        )

    def test_intent_without_metadata(self):
        key = uuid.uuid4()
        self.journal.record_intent(
            key, hashlib.sha256(PDF).hexdigest()
        )
        self.store.put_quarantine(key, PDF)

        result = self.audit()
        self.assertEqual(result["metadata_missing"], 1)
        self.assertTrue(result["requires_review"])
        self.assertTrue(
            (self.private / key.hex).exists()
        )

    def test_metadata_without_intent(self):
        RenewalAttachment.objects.create(
            renewal=self.renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(PDF),
            sha256=hashlib.sha256(PDF).hexdigest(),
            state="quarantined",
        )

        result = self.audit()
        self.assertEqual(result["intent_missing"], 1)
        self.assertTrue(result["requires_review"])

    def test_missing_object(self):
        item = self.intake()
        self.store.discard_quarantine(item.storage_key)

        result = self.audit()
        self.assertEqual(result["object_missing"], 1)
        self.assertFalse(result["release_authorized"])

    def test_metadata_digest_mismatch(self):
        item = self.intake()
        item.sha256 = "f" * 64
        item.save(update_fields=["sha256"])

        result = self.audit()
        self.assertEqual(result["mismatch"], 1)
        self.assertTrue(result["requires_review"])

    def test_unavailable_volume(self):
        item = self.intake()
        # Ocultar temporalmente la ruta, sin borrar archivos.
        hidden = self.private.with_name("private_hidden")
        self.private.rename(hidden)
        try:
            result = self.audit()
            self.assertEqual(result["unavailable"], 1)
            self.assertFalse(result["release_authorized"])
        finally:
            hidden.rename(self.private)

        self.assertTrue(
            (self.private / item.storage_key.hex).exists()
        )
