"""B06D: integración cooperativa con PostgreSQL 17 temporal."""
from datetime import date
from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace, WorkspaceMember
from .offline_intake import stage_authorized_attachment


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B06DCooperativeIntakeTests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        user = get_user_model().objects.create_user(
            username="b06d_synthetic_owner"
        )
        ws = Workspace.objects.create(name="B06D SYNTHETIC")
        self.member = WorkspaceMember.objects.create(
            workspace=ws,
            user=user,
            role=WorkspaceMember.Role.OWNER,
        )
        self.renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B06D-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )

    def invoke(self):
        return stage_authorized_attachment(
            member=self.member,
            renewal_id=self.renewal.pk,
            store=Mock(),
            filename="synthetic.pdf",
            content_type="application/pdf",
            content=b"%PDF-1.4\nsynthetic\n%%EOF",
        )

    def test_staging_acquires_shared_barrier(self):
        class BarrierEntered(Exception):
            pass

        from contextlib import contextmanager

        @contextmanager
        def sentinel(*, capture=False, timeout=5.0):
            self.assertFalse(capture)
            raise BarrierEntered()
            yield

        with patch(
            "renewal_attachments.offline_intake.advisory_barrier",
            sentinel,
        ):
            with self.assertRaises(BarrierEntered):
                self.invoke()

    def test_cannot_stage_in_production(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.invoke()

    def test_staging_rejects_sqlite_mode(self):
        # En PostgreSQL permanece activa la barrera de ensayo.
        # No permitimos retirar el guard para usar otro motor.
        from .offline_write_barrier_b06b import _guard
        with patch(
            "renewal_attachments.offline_write_barrier_b06b.connection.vendor",
            "sqlite",
        ):
            with self.assertRaises(PermissionDenied):
                _guard()
