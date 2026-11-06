"""G14-C disposable transactional invariants, not a trusted issuer.

These tests deliberately call the test-only issuer primitive. They DO NOT
supply a proof of password/TOTP verification and must never expose HTTP routes.
"""
import uuid

from django.contrib.auth import get_user_model
from django.db import transaction
from django.test import TestCase, override_settings

from .g5_audit import MobileAuditDenied, record_candidate_auth_event
from .models import MobileAuthAuditEvent, MobileDeviceSession
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session,
    revoke_all_candidate_devices, validate_candidate_access,
)


@override_settings(
    VENCIRA_G5_AUDIT_KEY="g14-c-disposable-audit-material-not-for-production",
)
class G14CandidateAtomicityTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="g14-c-disposable-user",
            password="g14-c-disposable-password",
        )

    def issue(self, generation=0):
        return issue_verified_candidate_session(
            user_id=self.user.pk, verified_mfa=False, mfa_epoch=None,
            expected_generation=generation,
        )

    def record(self, event_id=None, kind="auth_verified"):
        return record_candidate_auth_event(
            event_id=event_id or uuid.uuid4(),
            event_type=kind,
            actor="g14-c-disposable-user",
        )

    def test_session_and_success_audit_commit_together(self):
        with transaction.atomic():
            access, _ = self.issue()
            self.record()
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)
        self.assertEqual(validate_candidate_access(access).pk, self.user.pk)

    def test_audit_unavailable_rolls_back_session(self):
        with self.assertRaises(MobileAuditDenied):
            with transaction.atomic():
                self.issue()
                with override_settings(VENCIRA_G5_AUDIT_KEY=None):
                    self.record()
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(MobileAuthAuditEvent.objects.exists())

    def test_conflicting_audit_event_rolls_back_new_session(self):
        event_id = uuid.uuid4()
        self.record(event_id=event_id, kind="auth_denied")
        with self.assertRaises(MobileAuditDenied):
            with transaction.atomic():
                self.issue()
                self.record(event_id=event_id, kind="auth_verified")
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)
        self.assertEqual(
            MobileAuthAuditEvent.objects.get().event_type, "auth_denied",
        )

    def test_transaction_abort_rolls_back_session_and_audit(self):
        with self.assertRaises(RuntimeError):
            with transaction.atomic():
                self.issue()
                self.record()
                raise RuntimeError("synthetic-crash-before-commit")
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(MobileAuthAuditEvent.objects.exists())

    def test_revocation_generation_denies_stale_issuance(self):
        old_access, _ = self.issue()
        revoke_all_candidate_devices(user_id=self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        with self.assertRaises(MobileTokenDenied):
            self.issue(generation=0)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(old_access)
        next_access, _ = self.issue(generation=1)
        self.assertEqual(validate_candidate_access(next_access).pk, self.user.pk)
