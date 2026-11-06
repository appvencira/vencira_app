"""B06E: barrera real de ensayo en rechazo y recuperación."""
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from threading import Event
from unittest.mock import Mock

from django.contrib.auth import get_user_model
from django.db import close_old_connections, connections, connection
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace, WorkspaceMember

from .models import RenewalAttachment, AttachmentDiscardJob
from .offline_rejection import reject_attachment_offline
from .offline_rejection_recovery import retry_rejected_discard_offline
from .offline_write_barrier_b06b import advisory_barrier


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B06EWritePathsPG17Tests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")

        user = get_user_model().objects.create_user(
            username="b06e_owner"
        )
        ws = Workspace.objects.create(name="B06E SYNTHETIC")
        self.member = WorkspaceMember.objects.create(
            workspace=ws,
            user=user,
            role=WorkspaceMember.Role.OWNER,
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B06E-TEST",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=12,
            sha256="a" * 64,
            state=RenewalAttachment.State.QUARANTINED,
        )

    def test_rejection_and_discard_under_barrier(self):
        store = Mock()
        result = reject_attachment_offline(
            member=self.member,
            attachment_id=self.item.pk,
            store=store,
        )
        self.assertTrue(result.private_object_discarded)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "rejected")

        job = AttachmentDiscardJob.objects.get(
            attachment=self.item
        )
        self.assertEqual(job.status, "completed")
        store.discard_quarantine.assert_called_once()

    def test_capture_blocks_rejection(self):
        started = Event()
        ended = Event()
        store = Mock()

        def worker():
            close_old_connections()
            try:
                started.set()
                result = reject_attachment_offline(
                    member=self.member,
                    attachment_id=self.item.pk,
                    store=store,
                )
                ended.set()
                return result
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(worker)
                self.assertTrue(started.wait(3))
                self.assertFalse(ended.wait(0.3))

            result = future.result(timeout=8)

        self.assertTrue(result.private_object_discarded)
        self.assertTrue(ended.is_set())

    def test_capture_blocks_discard_retry(self):
        self.item.state = RenewalAttachment.State.REJECTED
        self.item.save(update_fields=["state"])
        AttachmentDiscardJob.objects.create(
            attachment=self.item
        )
        started = Event()
        ended = Event()

        def worker():
            close_old_connections()
            try:
                started.set()
                result = retry_rejected_discard_offline(
                    member=self.member,
                    attachment_id=self.item.pk,
                    store=Mock(),
                )
                ended.set()
                return result
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(worker)
                self.assertTrue(started.wait(3))
                self.assertFalse(ended.wait(0.3))

            result = future.result(timeout=8)

        self.assertTrue(result.private_object_discarded)
        self.assertTrue(ended.is_set())
