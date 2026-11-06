"""B18C: prove a non-cooperative DB writer bypasses PG advisory capture.

Demonstrates a BLOCKER, not a safe operational capture. PG17 test only.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from threading import Event

from django.db import close_old_connections, connections, connection
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace
from .models import RenewalAttachment, AttachmentRecoveryCase
from .offline_write_barrier_b06b import advisory_barrier


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B18CNonCooperativeWriterPG17Tests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(name="B18C SYNTHETIC")
        renewal = Renewal.objects.create(
            workspace=ws, full_name="Synthetic",
            customer_reference="B18C-ONLY",
            expires_on=date(2027, 12, 1),
        )
        self.attachment = RenewalAttachment.objects.create(
            renewal=renewal, display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=1,
            sha256="a" * 64, state="quarantined",
        )

    def test_raw_orm_writer_bypasses_cooperative_barrier(self):
        started = Event()

        def uncooperative_writer():
            close_old_connections()
            try:
                started.set()
                return AttachmentRecoveryCase.objects.create(
                    attachment_id=self.attachment.pk,
                    status="review_required",
                    classification="verified",
                    attempts=1,
                ).pk
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(uncooperative_writer)
                self.assertTrue(started.wait(3))
                # This SHOULD succeed even while exclusive capture is held:
                # direct ORM writes do not participate in PG advisory locks.
                pk = future.result(timeout=5)
                self.assertTrue(
                    AttachmentRecoveryCase.objects.filter(pk=pk).exists()
                )
        self.assertTrue(AttachmentRecoveryCase.objects.filter(pk=pk).exists())
