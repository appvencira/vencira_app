"""D1.5-S1B: esquema administrativo aislado, sin rutas para reset."""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.utils import timezone
from .models import (
    MfaAdministrativeRecoveryCase, MfaAdministrativeRecoveryApproval,
    MfaAdministrativeRecoveryEvent, UserMfaState,
)


class RecoveryEntitiesTests(TestCase):
    def setUp(self):
        U = get_user_model()
        self.subject = U.objects.create_user(username="mfa_subject_s1b", password="SyntheticPassword!123")
        self.reviewer = U.objects.create_user(username="mfa_reviewer_s1b", password="SyntheticPassword!123")
        self.case = MfaAdministrativeRecoveryCase.objects.create(
            subject=self.subject, requester=self.subject,
            quarantine_until=timezone.now() + timedelta(hours=24),
            expires_at=timezone.now() + timedelta(hours=72),
        )

    def test_case_pending_cannot_change_mfa_factors(self):
        UserMfaState.objects.create(
            user=self.subject, encrypted_totp_secret="synthetic-only",
            enabled=True,
        )
        MfaAdministrativeRecoveryApproval.objects.create(
            case=self.case, reviewer=self.reviewer,
            expires_at=timezone.now() + timedelta(hours=12),
        )
        self.assertTrue(UserMfaState.objects.get(user=self.subject).enabled)
        self.assertEqual(self.case.status, "pending")

    def test_duplicate_reviewer_is_rejected(self):
        expiry = timezone.now() + timedelta(hours=12)
        MfaAdministrativeRecoveryApproval.objects.create(
            case=self.case, reviewer=self.reviewer, expires_at=expiry,
        )
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                MfaAdministrativeRecoveryApproval.objects.create(
                    case=self.case, reviewer=self.reviewer, expires_at=expiry,
                )
        self.assertEqual(self.case.approvals.count(), 1)

    def test_audit_event_can_be_recorded_without_sensitive_values(self):
        MfaAdministrativeRecoveryEvent.objects.create(
            case=self.case, actor=self.reviewer, action="review_requested",
        )
        self.assertEqual(self.case.events.count(), 1)
        self.assertEqual(self.case.events.get().action, "review_requested")
