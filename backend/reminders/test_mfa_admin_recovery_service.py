"""S1C: pruebas sintéticas de la primitiva interna de revisión."""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from .mfa_admin_recovery_service import record_review
from .models import MfaAdministrativeRecoveryCase as Case, UserMfaState


class RecoveryReviewServiceTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.subject = User.objects.create_user("recover_subject", password="TestPassword123!")
        self.reviewer1 = User.objects.create_user("recover_review1", password="TestPassword123!", is_staff=True)
        self.reviewer2 = User.objects.create_user("recover_review2", password="TestPassword123!", is_staff=True)
        self.now = timezone.now()
        self.case = Case.objects.create(
            subject=self.subject, requester=self.subject,
            channel_verified_at=self.now,
            quarantine_until=self.now + timedelta(hours=24),
            expires_at=self.now + timedelta(hours=72),
        )
        # auto_now_add asigna created_at al guardar; el reloj de la petición
        # debe capturarse después de que exista el caso.
        self.now = timezone.now()

    def test_two_distinct_approvals_are_recorded_once_without_reset(self):
        UserMfaState.objects.create(user=self.subject, enabled=True, encrypted_totp_secret="synthetic")
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer1, approve=True, now=self.now),
                         (True, "APPROVAL_RECORDED"))
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer1, approve=True, now=self.now),
                         (True, "ALREADY_RECORDED"))
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer2, approve=True, now=self.now),
                         (True, "APPROVAL_RECORDED"))
        self.assertEqual(self.case.approvals.count(), 2)
        self.assertEqual(self.case.events.count(), 2)
        self.assertTrue(UserMfaState.objects.get(user=self.subject).enabled)

    def test_unprivileged_and_subject_cannot_approve(self):
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.subject, approve=True, now=self.now)[0], False)
        outsider = get_user_model().objects.create_user("outsider_reviewer", password="TestPassword123!")
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=outsider, approve=True, now=self.now)[0], False)
        self.assertEqual(self.case.approvals.count(), 0)

    def test_unverified_or_expired_case_fails(self):
        self.case.channel_verified_at = None
        self.case.save(update_fields=["channel_verified_at"])
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer1, approve=True, now=self.now)[0], False)
        self.case.channel_verified_at = self.now
        self.case.expires_at = self.now
        self.case.save(update_fields=["channel_verified_at", "expires_at"])
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer1, approve=True, now=self.now)[0], False)

    def test_rejection_is_terminal_and_audited(self):
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer1, approve=False, now=self.now),
                         (True, "REJECTED"))
        self.assertEqual(record_review(case_id=self.case.pk, reviewer=self.reviewer2, approve=True, now=self.now),
                         (False, "CASE_NOT_PENDING"))
        self.assertEqual(self.case.events.count(), 1)
