"""G5 shared throttle races; disposable PostgreSQL17 only, no live sessions."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.db import connection, connections
from django.test import TransactionTestCase, override_settings

from .g5_throttle import consume_candidate_auth_attempt
from .models import MobileAuthAttemptBucket


@override_settings(VENCIRA_G5_ABUSE_KEY="g5-only-synthetic-test-material-2026-not-production")
class G5ThrottlePG17Races(TransactionTestCase):
    def test_five_parallel_attempts_same_account_have_exactly_one_denied(self):
        if connection.vendor != "postgresql":
            self.skipTest("requires PostgreSQL row-level locking")
        barrier = Barrier(6)

        def worker(n):
            connections.close_all()
            try:
                barrier.wait(timeout=15)
                return consume_candidate_auth_attempt(
                    account_key="same-synthetic-account",
                    request_meta={"REMOTE_ADDR": f"203.0.113.{n+1}"},
                )
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=5) as pool:
            futures = [pool.submit(worker, n) for n in range(5)]
            barrier.wait(timeout=15)
            outcomes = [future.result(timeout=40) for future in futures]

        self.assertEqual(outcomes.count(True), 4)
        self.assertEqual(outcomes.count(False), 1)
        account = MobileAuthAttemptBucket.objects.get(scope="account")
        self.assertEqual(account.attempt_count, 5)
        self.assertIsNotNone(account.blocked_until)
        self.assertEqual(MobileAuthAttemptBucket.objects.filter(scope="ip").count(), 5)
