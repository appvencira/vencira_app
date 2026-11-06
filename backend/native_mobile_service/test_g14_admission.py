"""G14 isolated account/IP admission and atomic denial audit tests."""
import uuid

from django.test import TestCase, override_settings

from .g14_admission import (
    CandidateAdmissionDenied, admit_candidate_password_attempt,
)
from .models import MobileAuthAttemptBucket, MobileAuthAuditEvent


@override_settings(
    VENCIRA_G5_ABUSE_KEY="g14-synthetic-abuse-key-not-production-2026",
    VENCIRA_G5_AUDIT_KEY="g14-synthetic-audit-key-not-production-2026",
)
class G14CandidateAdmissionTests(TestCase):
    def attempt(self, *, account="synthetic@example.invalid",
                ip="198.51.100.7", event_id=None, **meta):
        return admit_candidate_password_attempt(
            account_key=account,
            request_meta={"REMOTE_ADDR": ip, **meta},
            denial_event_id=event_id or uuid.uuid4(),
        )

    def test_allows_first_four_without_claiming_authentication(self):
        for _ in range(4):
            self.assertIs(self.attempt(), True)
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 0)
        self.assertEqual(MobileAuthAttemptBucket.objects.count(), 2)

    def test_fifth_attempt_denied_and_redacted_audit_written(self):
        for _ in range(4):
            self.assertTrue(self.attempt())
        self.assertFalse(self.attempt())
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)
        event = MobileAuthAuditEvent.objects.get()
        self.assertEqual(event.event_type, "auth_denied")
        self.assertEqual(len(event.actor_digest), 64)
        self.assertNotIn("synthetic", event.actor_digest)

    def test_missing_audit_key_denies_before_consuming_budget(self):
        with override_settings(VENCIRA_G5_AUDIT_KEY=None):
            with self.assertRaises(CandidateAdmissionDenied):
                self.attempt()
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())

    def test_missing_abuse_key_denies_before_verification(self):
        with override_settings(VENCIRA_G5_ABUSE_KEY=None):
            with self.assertRaises(CandidateAdmissionDenied):
                self.attempt()
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())

    def test_reused_denial_uuid_with_conflicting_actor_rolls_back(self):
        for _ in range(4):
            self.assertTrue(self.attempt())
        event_id = uuid.uuid4()
        self.assertFalse(self.attempt(event_id=event_id))
        for _ in range(4):
            self.assertTrue(self.attempt(account="another@example.invalid", ip="203.0.113.8"))
        with self.assertRaises(CandidateAdmissionDenied):
            self.attempt(account="another@example.invalid", ip="203.0.113.8", event_id=event_id)
        account_buckets = MobileAuthAttemptBucket.objects.filter(scope="account")
        self.assertEqual(sorted(row.attempt_count for row in account_buckets), [4, 5])
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)

    def test_invalid_forwarding_from_trusted_peer_fails_closed(self):
        with self.assertRaises(CandidateAdmissionDenied):
            admit_candidate_password_attempt(
                account_key="synthetic@example.invalid",
                request_meta={
                    "REMOTE_ADDR": "192.0.2.10",
                    "HTTP_X_FORWARDED_FOR": "198.51.100.1, 198.51.100.2",
                },
                trusted_proxy_ips=("192.0.2.10",),
                denial_event_id=uuid.uuid4(),
            )
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())

    def test_not_available_outside_candidate_test_environment(self):
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            with self.assertRaises(CandidateAdmissionDenied):
                self.attempt()
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())

    def test_requires_uuid_without_consuming_budget(self):
        with self.assertRaises(CandidateAdmissionDenied):
            self.attempt(event_id="not-a-uuid")
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())
