"""D7B: pruebas reales del outbox Django sobre PostgreSQL efímero."""
import threading
import time
from datetime import date
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import Mock

from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection, connections
from django.test import TransactionTestCase, override_settings

from reminders.attachment_private_store import PrivateStoreError
from reminders.models import Renewal, Workspace, WorkspaceMember
from .models import RenewalAttachment, AttachmentDiscardJob
from .offline_rejection_recovery import retry_rejected_discard_offline


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D7BPostgresTests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")

        user = get_user_model().objects.create_user(
            username="d7b_synthetic_owner"
        )
        ws = Workspace.objects.create(name="D7B SYNTHETIC")
        self.member = WorkspaceMember.objects.create(
            workspace=ws, user=user, role=WorkspaceMember.Role.OWNER
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="D7B-SYNTHETIC",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=10,
            sha256="a" * 64,
            state=RenewalAttachment.State.REJECTED,
        )
        self.job = AttachmentDiscardJob.objects.create(
            attachment=self.item
        )

    def retry(self, store):
        return retry_rejected_discard_offline(
            member=self.member,
            attachment_id=self.item.pk,
            store=store,
        )

    def test_success_is_idempotent(self):
        store = Mock()
        self.retry(store)
        self.retry(store)

        self.job.refresh_from_db()
        self.assertEqual(self.job.status, "completed")
        self.assertEqual(self.job.attempts, 1)
        store.discard_quarantine.assert_called_once()

    def test_storage_failure_then_retry(self):
        store = Mock()
        store.discard_quarantine.side_effect = [
            PrivateStoreError("SYNTHETIC_FAILURE"),
            None,
        ]

        self.retry(store)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, "pending")
        self.assertEqual(self.job.attempts, 1)

        self.retry(store)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, "completed")
        self.assertEqual(self.job.attempts, 2)
        self.assertEqual(store.discard_quarantine.call_count, 2)

    def test_concurrent_workers_discard_once(self):
        entered = threading.Event()
        release = threading.Event()
        calls = []
        errors = []

        class SlowStore:
            def discard_quarantine(self, key):
                calls.append(key)
                entered.set()
                if not release.wait(10):
                    raise PrivateStoreError("SYNTHETIC_TIMEOUT")

        store = SlowStore()

        def worker():
            close_old_connections()
            try:
                return self.retry(store)
            finally:
                # Los hilos deben cerrar sus conexiones PostgreSQL
                # antes de que Django destruya la BD de pruebas.
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(worker)
            try:
                self.assertTrue(entered.wait(10))
                second = pool.submit(worker)
                time.sleep(0.4)
                self.assertFalse(second.done())
            finally:
                release.set()

            for future in (first, second):
                try:
                    future.result(timeout=15)
                except Exception as exc:
                    errors.append(repr(exc))

        self.assertFalse(errors, errors)
        self.assertEqual(len(calls), 1)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status, "completed")
        self.assertEqual(self.job.attempts, 1)
