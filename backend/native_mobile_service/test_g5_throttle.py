"""G5 candidate account/IP limits. Synthetic identifiers and disposable test DB."""
from django.test import TestCase, override_settings

from .g5_throttle import CandidateThrottleDenied, consume_candidate_auth_attempt
from .models import MobileAuthAttemptBucket


@override_settings(VENCIRA_G5_ABUSE_KEY="g5-only-synthetic-test-material-2026-not-production")
class G5ThrottleContractTests(TestCase):
    def consume(self, account="synthetic@example.invalid", ip="198.51.100.9"):
        return consume_candidate_auth_attempt(
            account_key=account, request_meta={"REMOTE_ADDR": ip},
        )

    def test_account_fifth_attempt_denied_and_hashes_only(self):
        for _ in range(4):
            self.assertTrue(self.consume())
        self.assertFalse(self.consume())
        self.assertEqual(MobileAuthAttemptBucket.objects.count(), 2)
        for row in MobileAuthAttemptBucket.objects.all():
            self.assertEqual(len(row.subject_digest), 64)
            self.assertNotIn("synthetic@", row.subject_digest)
            self.assertNotIn("198.51", row.subject_digest)

    def test_same_account_across_many_ips_is_shared(self):
        for n in range(4):
            self.assertTrue(self.consume(ip=f"203.0.113.{n+1}"))
        self.assertFalse(self.consume(ip="203.0.113.99"))

    def test_same_ip_across_distinct_accounts_is_shared(self):
        for n in range(19):
            self.assertTrue(self.consume(account=f"synthetic-{n}"))
        self.assertFalse(self.consume(account="synthetic-20"))

    def test_blocked_account_does_not_disclose_identity(self):
        for _ in range(5):
            self.consume()
        self.assertFalse(self.consume())
        self.assertEqual(MobileAuthAttemptBucket.objects.filter(scope="account").count(), 1)

    def test_proxy_spoof_cannot_change_ip_bucket(self):
        for n in range(19):
            allowed = consume_candidate_auth_attempt(
                account_key=f"user-{n}",
                request_meta={
                    "REMOTE_ADDR": "198.51.100.1",
                    "HTTP_X_FORWARDED_FOR": f"203.0.113.{n+1}",
                },
            )
            self.assertTrue(allowed)
        self.assertFalse(consume_candidate_auth_attempt(
            account_key="user-final",
            request_meta={
                "REMOTE_ADDR": "198.51.100.1",
                "HTTP_X_FORWARDED_FOR": "203.0.113.250",
            },
        ))

    def test_missing_key_fails_closed(self):
        with override_settings(VENCIRA_G5_ABUSE_KEY=None):
            with self.assertRaises(CandidateThrottleDenied):
                self.consume()

    def test_invalid_account_fails_closed(self):
        for key in ("", " leading", "trailing ", "a" * 255, None):
            with self.subTest(key=key):
                with self.assertRaises(CandidateThrottleDenied):
                    self.consume(account=key)

    def test_unregistered_mode_denied(self):
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            with self.assertRaises(CandidateThrottleDenied):
                self.consume()
