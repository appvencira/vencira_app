import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import date

from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.db import connection, connections, close_old_connections
from django.test import TransactionTestCase, override_settings

from reminders.models import Renewal, Workspace
from .models import RenewalAttachment, AttachmentRecoveryCase
from .offline_recovery_persistence_d10 import record_recovery_offline
from .offline_write_barrier_b06b import advisory_barrier


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class D10PersistentPostgresTests(TransactionTestCase):
    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(name="D10 SYNTHETIC")
        renewal = Renewal.objects.create(
            workspace=ws,
            full_name="Synthetic",
            customer_reference="D10-TEST",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=10,
            sha256="a" * 64,
            state="quarantined",
        )

    def record(self, classification="verified"):
        return record_recovery_offline(
            attachment_id=self.item.pk,
            classification=classification,
        )

    def test_persistent_state(self):
        case = self.record()
        self.assertEqual(case.status, "review_required")
        reopened = AttachmentRecoveryCase.objects.get(
            attachment=self.item
        )
        self.assertEqual(reopened.pk, case.pk)

    def test_idempotent_retry(self):
        first = self.record()
        second = self.record()
        self.assertEqual(first.pk, second.pk)
        self.assertEqual(second.attempts, 1)

    def test_unavailable_requires_retry(self):
        case = self.record("unavailable")
        self.assertEqual(case.status, "retry_required")

    def test_conflicting_recovery_cannot_overwrite(self):
        self.record("missing")
        with self.assertRaises(PermissionDenied):
            self.record("verified")
        case = AttachmentRecoveryCase.objects.get(
            attachment=self.item
        )
        self.assertEqual(case.classification, "missing")

    def test_rejected_attachment_cannot_start_recovery(self):
        self.item.state = "rejected"
        self.item.save(update_fields=["state"])
        with self.assertRaises(PermissionDenied):
            self.record()
        self.assertFalse(
            AttachmentRecoveryCase.objects.filter(
                attachment=self.item
            ).exists()
        )

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.record()

    def test_concurrent_initial_creation_once(self):
        start = threading.Barrier(2)
        errors = []

        def worker():
            close_old_connections()
            try:
                start.wait(timeout=10)
                return self.record().pk
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(worker) for _ in range(2)]
            results = []
            for future in futures:
                try:
                    results.append(future.result(timeout=20))
                except Exception as exc:
                    errors.append(repr(exc))

        self.assertFalse(errors, errors)
        self.assertEqual(results[0], results[1])
        self.assertEqual(
            AttachmentRecoveryCase.objects.filter(
                attachment=self.item
            ).count(),
            1,
        )

    def test_capture_blocks_recovery_write(self):
        entered = threading.Event()
        finished = threading.Event()

        def worker():
            close_old_connections()
            try:
                entered.set()
                result = self.record()
                finished.set()
                return result.pk
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(worker)
                self.assertTrue(entered.wait(3))
                self.assertFalse(finished.wait(0.25))
                self.assertFalse(
                    AttachmentRecoveryCase.objects.filter(
                        attachment=self.item
                    ).exists()
                )
            pk = future.result(timeout=8)
        self.assertTrue(finished.is_set())
        self.assertTrue(
            AttachmentRecoveryCase.objects.filter(pk=pk).exists()
        )
