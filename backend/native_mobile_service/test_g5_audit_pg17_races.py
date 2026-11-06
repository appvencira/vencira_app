"""G5 candidate audit concurrency; isolated PostgreSQL 17 only."""
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.db import connection, connections
from django.test import TransactionTestCase, override_settings

from .g5_audit import record_candidate_auth_event, MobileAuditDenied
from .models import MobileAuthAuditEvent


@override_settings(VENCIRA_G5_AUDIT_KEY="g5-audit-only-synthetic-key-material-2026-not-production")
class G5AuditPG17Races(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL17 concurrent insert required")

    def test_parallel_same_uuid_deduplicates_one_event(self):
        event_id = uuid.uuid4()
        barrier = Barrier(3)

        def worker():
            connections.close_all()
            try:
                barrier.wait(timeout=15)
                _, created = record_candidate_auth_event(
                    event_id=event_id, event_type="auth_denied",
                    actor="synthetic-account",
                )
                return created
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            first, second = pool.submit(worker), pool.submit(worker)
            barrier.wait(timeout=15)
            results = [first.result(timeout=40), second.result(timeout=40)]
        self.assertEqual(sorted(results), [False, True])
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)

    def test_parallel_conflicting_payload_rejected(self):
        event_id = uuid.uuid4()
        barrier = Barrier(3)

        def worker(event_type):
            connections.close_all()
            try:
                barrier.wait(timeout=15)
                try:
                    record_candidate_auth_event(
                        event_id=event_id, event_type=event_type,
                    )
                    return "accepted"
                except MobileAuditDenied:
                    return "denied"
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(worker, "auth_denied")
            second = pool.submit(worker, "device_logout")
            barrier.wait(timeout=15)
            results = [first.result(timeout=40), second.result(timeout=40)]
        self.assertEqual(sorted(results), ["accepted", "denied"])
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)
