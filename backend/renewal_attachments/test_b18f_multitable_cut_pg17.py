"""B18F: two-table DB fence versus direct ORM writes, disposable PG17.

Negative evidence: filesystem operations are not held by SQL table locks.
No operational capture or filesystem claims.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from threading import Event
import tempfile
from pathlib import Path

from django.db import close_old_connections, connection, connections, transaction
from django.test import TransactionTestCase, override_settings
from reminders.models import Workspace, Renewal
from .models import RenewalAttachment, AttachmentRecoveryCase


@override_settings(VENCIRA_ENV="test", VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True)
class B18FMultiTableCutTests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(name="B18F SYNTHETIC")
        ren = Renewal.objects.create(
            workspace=ws, customer_reference="B18F", full_name="Synthetic",
            expires_on=date(2027, 12, 1))
        self.attachment = RenewalAttachment.objects.create(
            renewal=ren, display_name="synthetic.pdf", content_type="application/pdf",
            byte_size=1, sha256="a"*64, state="quarantined")

    def test_two_table_fence_blocks_direct_orm_writes(self):
        start = Event()
        completed = Event()

        def writer():
            close_old_connections()
            try:
                start.set()
                RenewalAttachment.objects.filter(pk=self.attachment.pk).update(
                    display_name="new.pdf")
                AttachmentRecoveryCase.objects.create(
                    attachment_id=self.attachment.pk, status="review_required",
                    classification="verified", attempts=1)
                completed.set()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with transaction.atomic():
                with connection.cursor() as cursor:
                    cursor.execute(
                        'LOCK TABLE "renewal_attachments_renewalattachment", '
                        '"renewal_attachments_attachmentrecoverycase" '
                        'IN ACCESS EXCLUSIVE MODE')
                future = pool.submit(writer)
                self.assertTrue(start.wait(3))
                self.assertFalse(completed.wait(0.3))
            future.result(timeout=8)
        self.assertTrue(completed.is_set())
        self.attachment.refresh_from_db()
        self.assertEqual(self.attachment.display_name, "new.pdf")
        self.assertTrue(AttachmentRecoveryCase.objects.filter(
            attachment=self.attachment).exists())

    def test_sql_fence_cannot_block_synthetic_journal_write(self):
        with tempfile.TemporaryDirectory(prefix="b18f-journal-") as tmp:
            target = Path(tmp) / "synthetic.json"
            with transaction.atomic():
                with connection.cursor() as cursor:
                    cursor.execute(
                        'LOCK TABLE "renewal_attachments_renewalattachment", '
                        '"renewal_attachments_attachmentrecoverycase" '
                        'IN ACCESS EXCLUSIVE MODE')
                # This succeeds despite DB locks: scope is database ONLY.
                target.write_bytes(b'{"version":1,"synthetic":true}')
                self.assertTrue(target.exists())
            self.assertEqual(target.read_bytes(),
                             b'{"version":1,"synthetic":true}')
