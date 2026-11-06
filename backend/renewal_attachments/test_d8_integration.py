"""D8: integración offline de autorización, diario y metadatos.

Solo contenido sintético. Sin endpoints ni trabajos automáticos.
"""
import tempfile
from datetime import date
from pathlib import Path
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.http import Http404
from django.test import TestCase, override_settings

from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.models import Renewal, Workspace, WorkspaceMember

from .models import RenewalAttachment
from .offline_intake import stage_authorized_attachment
from .offline_intake_journal import IntakeJournal
from .offline_recovery_d6 import classify_object


PDF = b"%PDF-1.4\nD8 SYNTHETIC\n%%EOF"


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D8IntegrationTests(TestCase):

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)

        base = Path(self.temp.name)
        self.private = base / "private"
        self.journal_root = base / "journal"

        self.private.mkdir(mode=0o700)
        self.journal_root.mkdir(mode=0o700)

        self.store = PrivateQuarantineStore(
            self.private, Fernet.generate_key()
        )
        self.journal = IntakeJournal(self.journal_root)

        user_model = get_user_model()
        self.owner = user_model.objects.create_user(
            username="d8_owner"
        )
        self.foreign = user_model.objects.create_user(
            username="d8_foreign"
        )

        self.workspace = Workspace.objects.create(
            name="D8 SYNTHETIC"
        )
        foreign_ws = Workspace.objects.create(
            name="D8 OTHER SYNTHETIC"
        )

        self.member = WorkspaceMember.objects.create(
            workspace=self.workspace,
            user=self.owner,
            role=WorkspaceMember.Role.OWNER,
        )
        self.foreign_member = WorkspaceMember.objects.create(
            workspace=foreign_ws,
            user=self.foreign,
            role=WorkspaceMember.Role.OWNER,
        )
        self.renewal = Renewal.objects.create(
            workspace=self.workspace,
            customer_reference="D8-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )

    def intake(self, member=None):
        return stage_authorized_attachment(
            member=self.member if member is None else member,
            renewal_id=self.renewal.pk,
            store=self.store,
            journal=self.journal,
            filename="synthetic.pdf",
            content_type="application/pdf",
            content=PDF,
        )

    def test_authorized_intake_links_all_three_layers(self):
        record = self.intake()

        self.assertEqual(
            RenewalAttachment.objects.count(), 1
        )
        self.assertEqual(
            record.renewal_id, self.renewal.pk
        )
        self.assertEqual(
            record.uploaded_by_id, self.owner.pk
        )
        self.assertEqual(record.state, "quarantined")

        intent = self.journal.read_intent(
            record.storage_key
        )
        self.assertEqual(
            intent["sha256"], record.sha256
        )

        self.assertEqual(
            classify_object(
                journal=self.journal,
                store=self.store,
                key=record.storage_key,
            ),
            "verified",
        )

        self.assertEqual(
            self.store.read_quarantine_for_scanner_only(
                record.storage_key
            ),
            PDF,
        )

    def test_foreign_workspace_cannot_create_intent(self):
        with self.assertRaises(Http404):
            self.intake(member=self.foreign_member)

        self.assertEqual(
            RenewalAttachment.objects.count(), 0
        )
        self.assertEqual(
            list(self.private.iterdir()), []
        )
        self.assertEqual(
            list(self.journal_root.iterdir()), []
        )

    def test_metadata_failure_keeps_recovery_intent(self):
        with patch(
            "renewal_attachments.offline_intake.attachment_model",
            side_effect=RuntimeError("D8_SYNTHETIC_METADATA_FAIL"),
        ):
            with self.assertRaisesRegex(
                RuntimeError, "D8_SYNTHETIC_METADATA_FAIL"
            ):
                self.intake()

        self.assertEqual(
            RenewalAttachment.objects.count(), 0
        )
        self.assertEqual(
            list(self.private.iterdir()), []
        )

        entries = list(self.journal_root.iterdir())
        self.assertEqual(len(entries), 1)

        # La intención queda pendiente para reconciliación.
        self.assertEqual(
            entries[0].suffix, ".json"
        )

    def test_production_mode_is_blocked(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.intake()

        self.assertEqual(
            list(self.private.iterdir()), []
        )
        self.assertEqual(
            list(self.journal_root.iterdir()), []
        )
