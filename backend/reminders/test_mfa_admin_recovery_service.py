"""S1C: pruebas sintéticas de la primitiva interna de revisión."""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from .mfa_admin_recovery_service import record_review, inspect_recovery_preconditions, cancel_recovery_case
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
        self.case.quarantine_until = self.case.created_at + timedelta(hours=24)
        self.case.expires_at = self.case.created_at + timedelta(hours=72)
        self.case.save(update_fields=["quarantine_until", "expires_at"])
        self.now = self.case.quarantine_until + timedelta(seconds=1)
        self.reviewers = (self.reviewer1.pk, self.reviewer2.pk)
        roster = override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=self.reviewers)
        roster.enable()
        self.addCleanup(roster.disable)

    def review(self, *, reviewer, approve):
        return record_review(case_id=self.case.pk, reviewer=reviewer,
                             approve=approve, now=self.now)

    def test_two_distinct_approvals_are_recorded_once_without_reset(self):
        UserMfaState.objects.create(user=self.subject, enabled=True, encrypted_totp_secret="synthetic")
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (True, "APPROVAL_RECORDED"))
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (True, "ALREADY_RECORDED"))
        self.assertEqual(self.review(reviewer=self.reviewer2, approve=True),
                         (True, "APPROVAL_RECORDED"))
        self.assertEqual(self.case.approvals.count(), 2)
        self.assertEqual(self.case.events.count(), 2)
        self.assertTrue(UserMfaState.objects.get(user=self.subject).enabled)

    def test_unprivileged_and_subject_cannot_approve(self):
        self.assertEqual(self.review(reviewer=self.subject, approve=True)[0], False)
        outsider = get_user_model().objects.create_user("outsider_reviewer", password="TestPassword123!")
        self.assertEqual(self.review(reviewer=outsider, approve=True)[0], False)
        self.assertEqual(self.case.approvals.count(), 0)

    def test_unverified_or_expired_case_fails(self):
        self.case.channel_verified_at = None
        self.case.save(update_fields=["channel_verified_at"])
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True)[0], False)
        self.case.channel_verified_at = self.now
        self.case.expires_at = self.now
        self.case.save(update_fields=["channel_verified_at", "expires_at"])
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True)[0], False)

    def test_rejection_is_terminal_and_audited(self):
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=False),
                         (True, "REJECTED"))
        self.assertEqual(self.review(reviewer=self.reviewer2, approve=True),
                         (False, "CASE_NOT_PENDING"))
        self.assertEqual(self.case.events.count(), 1)

    def test_missing_roster_and_active_quarantine_fail_closed(self):
        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=()):
            self.assertEqual(record_review(
                case_id=self.case.pk, reviewer=self.reviewer1,
                approve=True, now=self.now
            ), (False, "REVIEWER_AUTHORIZATION_REQUIRED"))
        self.assertEqual(record_review(
            case_id=self.case.pk, reviewer=self.reviewer1,
            approve=True,
            now=self.case.created_at + timedelta(minutes=1)
        ), (False, "QUARANTINE_ACTIVE"))

    def test_expired_approval_blocks_replay_and_new_approver(self):
        from .models import MfaAdministrativeRecoveryApproval as Approval
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (True, "APPROVAL_RECORDED"))
        Approval.objects.filter(case=self.case, reviewer=self.reviewer1).update(
            expires_at=self.now - timedelta(seconds=1))
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (False, "APPROVAL_EXPIRED"))
        self.assertEqual(self.review(reviewer=self.reviewer2, approve=True),
                         (False, "EXPIRED_APPROVAL_IN_CASE"))
        self.assertEqual(self.case.approvals.count(), 1)

    def test_previous_approval_cannot_be_reinterpreted_as_rejection(self):
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (True, "APPROVAL_RECORDED"))
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=False),
                         (False, "REVIEW_ALREADY_RECORDED"))
        self.case.refresh_from_db()
        self.assertEqual(self.case.status, "pending")

    def test_inspection_uses_persisted_approvals_and_never_resets(self):
        UserMfaState.objects.create(
            user=self.subject, enabled=True, encrypted_totp_secret="synthetic"
        )
        self.assertEqual(inspect_recovery_preconditions(
            case_id=self.case.pk, now=self.now
        ), (False, "TWO_APPROVALS_REQUIRED"))
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True)[0], True)
        self.assertEqual(self.review(reviewer=self.reviewer2, approve=True)[0], True)
        self.assertEqual(inspect_recovery_preconditions(
            case_id=self.case.pk, now=self.now
        ), (True, "POLICY_PRECONDITIONS_MET_ONLY"))
        self.assertTrue(UserMfaState.objects.get(user=self.subject).enabled)

    def test_inspection_rejects_expired_approval(self):
        from .models import MfaAdministrativeRecoveryApproval as Approval
        self.assertTrue(self.review(reviewer=self.reviewer1, approve=True)[0])
        self.assertTrue(self.review(reviewer=self.reviewer2, approve=True)[0])
        Approval.objects.filter(case=self.case, reviewer=self.reviewer1).update(
            expires_at=self.now - timedelta(seconds=1)
        )
        self.assertEqual(inspect_recovery_preconditions(
            case_id=self.case.pk, now=self.now
        ), (False, "EXPIRED_APPROVAL"))

    def test_duplicate_roster_id_does_not_enable_administrative_review(self):
        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=(
            self.reviewer1.pk, self.reviewer1.pk
        )):
            self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                             (False, "REVIEWER_AUTHORIZATION_REQUIRED"))

    def test_reviewer_revoked_after_approval_blocks_inspection(self):
        self.assertTrue(self.review(reviewer=self.reviewer1, approve=True)[0])
        self.assertTrue(self.review(reviewer=self.reviewer2, approve=True)[0])
        self.reviewer2.is_staff = False
        self.reviewer2.save(update_fields=["is_staff"])
        self.assertEqual(inspect_recovery_preconditions(
            case_id=self.case.pk, now=self.now
        ), (False, "REVIEWER_NOT_ELIGIBLE"))

    def test_case_past_72_hours_cannot_be_approved(self):
        expired = self.case.created_at + timedelta(hours=72, seconds=1)
        self.case.expires_at = expired + timedelta(hours=24)
        self.case.save(update_fields=["expires_at"])
        self.assertEqual(record_review(
            case_id=self.case.pk, reviewer=self.reviewer1,
            approve=True, now=expired
        ), (False, "CASE_EXPIRED"))

    def test_subject_can_cancel_once_and_approvals_then_blocked(self):
        UserMfaState.objects.create(
            user=self.subject, enabled=True, encrypted_totp_secret="synthetic"
        )
        self.assertEqual(cancel_recovery_case(
            case_id=self.case.pk, actor=self.subject
        ), (True, "CASE_CANCELLED"))
        self.assertEqual(cancel_recovery_case(
            case_id=self.case.pk, actor=self.subject
        ), (True, "ALREADY_CANCELLED"))
        self.assertEqual(self.review(reviewer=self.reviewer1, approve=True),
                         (False, "CASE_NOT_PENDING"))
        self.assertEqual(self.case.events.filter(action="cancelled").count(), 1)
        self.assertTrue(UserMfaState.objects.get(user=self.subject).enabled)

    def test_nonparticipant_cannot_cancel_case(self):
        self.assertEqual(cancel_recovery_case(
            case_id=self.case.pk, actor=self.reviewer1
        ), (False, "ACTOR_NOT_AUTHORIZED"))
        self.case.refresh_from_db()
        self.assertEqual(self.case.status, Case.Status.PENDING)
