"""D12: diferencias de esquemas con registros sintéticos."""
from datetime import date

from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.models import (
    Renewal, Workspace,
    RenewalAttachment as Historical,
)
from .models import RenewalAttachment as Independent
from .offline_transition_d12 import inspect_transition_d12


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D12TransitionPG17Tests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(name="D12 SYNTHETIC")
        self.renewal = Renewal.objects.create(
            workspace=ws, full_name="Synthetic",
            customer_reference="D12-SYNTHETIC",
            expires_on=date(2027, 12, 1),
        )

    def old(self):
        return Historical.objects.create(
            renewal=self.renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=10,
            sha256="a" * 64,
            state="quarantined",
        )

    def mirror(self, old):
        copied = Independent.objects.create(
            id=old.id,
            renewal=old.renewal,
            uploaded_by=old.uploaded_by,
            display_name=old.display_name,
            content_type=old.content_type,
            byte_size=old.byte_size,
            sha256=old.sha256,
            storage_key=old.storage_key,
            state=old.state,
        )
        # auto_now_add sobrescribe la fecha durante INSERT.
        # La restauramos explícitamente con UPDATE.
        Independent.objects.filter(pk=copied.pk).update(
            created_at=old.created_at
        )
        copied.refresh_from_db()
        return copied

    def test_empty_schemas_do_not_authorize_release(self):
        result = inspect_transition_d12()
        self.assertTrue(result["empty"])
        self.assertFalse(result["release_authorized"])

    def test_unmigrated_historical_record_detected(self):
        self.old()
        result = inspect_transition_d12()
        self.assertEqual(result["historical_only"], 1)
        self.assertTrue(result["requires_review"])

    def test_matching_copy(self):
        old = self.old()
        self.mirror(old)
        result = inspect_transition_d12()
        self.assertEqual(result["matching"], 1)
        self.assertFalse(result["requires_review"])
        self.assertFalse(result["release_authorized"])

    def test_digest_mismatch_detected(self):
        old = self.old()
        new = self.mirror(old)
        new.sha256 = "b" * 64
        new.save(update_fields=["sha256"])
        result = inspect_transition_d12()
        self.assertEqual(result["mismatched"], 1)
        self.assertTrue(result["requires_review"])

    def test_independent_only_detected(self):
        Independent.objects.create(
            renewal=self.renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=10,
            sha256="a" * 64,
        )
        result = inspect_transition_d12()
        self.assertEqual(result["independent_only"], 1)

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                inspect_transition_d12()
