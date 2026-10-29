"""B18D experimental DB-enforced capture fence, disposable PG17 only.

Postgres ACCESS EXCLUSIVE table locks block *noncooperative SQL writers*.
This does not freeze filesystem/object storage/journal and is NOT a
production capture implementation.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from threading import Event

from django.db import connection, close_old_connections, connections, transaction
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace
from .models import RenewalAttachment, AttachmentRecoveryCase


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B18DDatabaseFencePG17Tests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(name="B18D SYNTHETIC")
        renewal = Renewal.objects.create(
            workspace=ws, full_name="Synthetic", customer_reference="B18D",
            expires_on=date(2027, 12, 1),
        )
        self.attachment = RenewalAttachment.objects.create(
            renewal=renewal, display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=1,
            sha256="a" * 64, state="quarantined",
        )

    def test_table_lock_blocks_noncooperative_recovery_insert(self):
        started = Event()
        completed = Event()

        def direct_writer():
            close_old_connections()
            try:
                started.set()
                result = AttachmentRecoveryCase.objects.create(
                    attachment_id=self.attachment.pk, status="review_required",
                    classification="verified", attempts=1,
                )
                completed.set()
                return result.pk
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with transaction.atomic():
                with connection.cursor() as cursor:
                    # DB-owned lock, unlike cooperative advisory locks.
                    cursor.execute(
                        'LOCK TABLE "renewal_attachments_attachmentrecoverycase" '
                        'IN ACCESS EXCLUSIVE MODE'
                    )
                future = pool.submit(direct_writer)
                self.assertTrue(started.wait(3))
                self.assertFalse(completed.wait(0.3))
            pk = future.result(timeout=8)
        self.assertTrue(completed.is_set())
        self.assertTrue(AttachmentRecoveryCase.objects.filter(pk=pk).exists())

    def test_failed_capture_transaction_releases_table_lock(self):
        try:
            with transaction.atomic():
                with connection.cursor() as cursor:
                    cursor.execute(
                        'LOCK TABLE "renewal_attachments_attachmentrecoverycase" '
                        'IN ACCESS EXCLUSIVE MODE'
                    )
                raise ValueError("synthetic capture failure")
        except ValueError:
            pass
        AttachmentRecoveryCase.objects.create(
            attachment=self.attachment, status="review_required",
            classification="verified", attempts=1,
        )
        self.assertEqual(AttachmentRecoveryCase.objects.count(), 1)
