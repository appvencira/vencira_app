"""D2: reconciliation and transaction rollback, synthetic test data only."""
from datetime import date

from django.test import TestCase

from reminders.models import (
    Renewal,
    RenewalAttachment as Legacy,
    Workspace,
)
from .models import RenewalAttachment as Independent
from .transition_preflight import inspect_attachment_transition
from .transition_reconciliation import inspect_reconciliation


class TransitionD2Tests(TestCase):
    def setUp(self):
        self.workspace = Workspace.objects.create(
            name="D2 synthetic workspace"
        )
        self.renewal = Renewal.objects.create(
            workspace=self.workspace,
            customer_reference="D2-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )

    def legacy(self):
        return Legacy.objects.create(
            renewal=self.renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=20,
            sha256="a" * 64,
        )

    def test_empty_transition_still_does_not_authorize_release(self):
        report = inspect_attachment_transition()
        comparison = inspect_reconciliation()
        self.assertTrue(report.safe_empty_transition)
        self.assertFalse(comparison.release_authorized)

    def test_legacy_records_block_transition_without_mutation(self):
        original = self.legacy()
        before = Legacy.objects.count()

        report = inspect_attachment_transition()
        comparison = inspect_reconciliation()

        self.assertFalse(report.safe_empty_transition)
        self.assertEqual(comparison.missing_in_independent, 1)
        self.assertEqual(Legacy.objects.count(), before)
        self.assertEqual(Independent.objects.count(), 0)
        self.assertTrue(Legacy.objects.filter(pk=original.pk).exists())

    def test_matching_metadata_still_does_not_authorize_release(self):
        original = self.legacy()
        Independent.objects.create(
            id=original.id,
            renewal=original.renewal,
            uploaded_by=original.uploaded_by,
            display_name=original.display_name,
            content_type=original.content_type,
            byte_size=original.byte_size,
            sha256=original.sha256,
            storage_key=original.storage_key,
            state=original.state,
        )

        report = inspect_reconciliation()
        self.assertEqual(report.conflicting_records, 0)
        self.assertEqual(report.missing_in_independent, 0)
        self.assertEqual(report.missing_in_legacy, 0)
        self.assertFalse(report.release_authorized)

    def test_synthetic_copy_rollback_preserves_legacy(self):
        from django.db import transaction

        original = self.legacy()

        try:
            with transaction.atomic():
                Independent.objects.create(
                    id=original.id,
                    renewal=original.renewal,
                    display_name=original.display_name,
                    content_type=original.content_type,
                    byte_size=original.byte_size,
                    sha256=original.sha256,
                    storage_key=original.storage_key,
                    state=original.state,
                )
                self.assertEqual(Independent.objects.count(), 1)
                raise RuntimeError("D2_SYNTHETIC_ROLLBACK")
        except RuntimeError as exc:
            self.assertEqual(str(exc), "D2_SYNTHETIC_ROLLBACK")

        self.assertEqual(Independent.objects.count(), 0)
        self.assertTrue(Legacy.objects.filter(pk=original.pk).exists())
