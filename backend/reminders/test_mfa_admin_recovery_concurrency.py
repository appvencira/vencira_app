"""S1: prueba de carrera con conexiones PostgreSQL independientes, nunca LIVE."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from .mfa_admin_recovery_service import record_review, cancel_recovery_case
from .models import MfaAdministrativeRecoveryApproval, MfaAdministrativeRecoveryCase


class MfaReviewConcurrencyTests(TransactionTestCase):
    def test_same_reviewer_race_only_one_approval_and_event(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requiere bloqueos reales SELECT FOR UPDATE de PostgreSQL")
        U = get_user_model()
        owner = U.objects.create_user(username="s1race_subject")
        reviewer = U.objects.create_user(username="s1race_reviewer", is_staff=True)
        alternate = U.objects.create_user(username="s1race_other", is_staff=True)
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=owner, requester=owner,
            quarantine_until=timezone.now() + timedelta(hours=24),
            expires_at=timezone.now() + timedelta(hours=72),
            channel_verified_at=timezone.now(),
        )
        case.quarantine_until = case.created_at + timedelta(hours=24)
        case.expires_at = case.created_at + timedelta(hours=72)
        case.save(update_fields=["quarantine_until", "expires_at"])
        instant = case.quarantine_until + timedelta(seconds=1)
        barrier = Barrier(2)

        def worker():
            close_old_connections()
            try:
                actor = U.objects.get(pk=reviewer.pk)
                barrier.wait(timeout=10)
                return record_review(case_id=case.pk, reviewer=actor,
                                     approve=True, now=instant)
            finally:
                connection.close()

        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=(reviewer.pk, alternate.pk)):
            with ThreadPoolExecutor(max_workers=2) as executor:
                futures = [executor.submit(worker) for _ in range(2)]
                results = [f.result(timeout=30) for f in futures]
        self.assertEqual(sorted(results), sorted([
            (True, "APPROVAL_RECORDED"), (True, "ALREADY_RECORDED")
        ]))
        self.assertEqual(MfaAdministrativeRecoveryApproval.objects.filter(case=case).count(), 1)
        self.assertEqual(case.events.filter(action="review_approved").count(), 1)

    def test_rejection_racing_with_approval_has_single_terminal_outcome(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        U = get_user_model()
        owner = U.objects.create_user(username="s1race_reject_subject")
        first = U.objects.create_user(username="s1race_reject_first", is_staff=True)
        second = U.objects.create_user(username="s1race_reject_second", is_staff=True)
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=owner, requester=owner,
            quarantine_until=timezone.now() + timedelta(hours=24),
            expires_at=timezone.now() + timedelta(hours=72),
            channel_verified_at=timezone.now(),
        )
        case.quarantine_until = case.created_at + timedelta(hours=24)
        case.expires_at = case.created_at + timedelta(hours=72)
        case.save(update_fields=["quarantine_until", "expires_at"])
        instant = case.quarantine_until + timedelta(seconds=1)
        barrier = Barrier(2)

        def worker(actor_id, approve):
            close_old_connections()
            try:
                actor = U.objects.get(pk=actor_id)
                barrier.wait(timeout=10)
                return record_review(
                    case_id=case.pk, reviewer=actor, approve=approve, now=instant
                )
            finally:
                connection.close()

        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=(first.pk, second.pk)):
            with ThreadPoolExecutor(max_workers=2) as executor:
                a = executor.submit(worker, first.pk, True)
                b = executor.submit(worker, second.pk, False)
                results = [a.result(timeout=30), b.result(timeout=30)]
        case.refresh_from_db()
        self.assertEqual(case.status, MfaAdministrativeRecoveryCase.Status.REJECTED)
        self.assertEqual(case.events.filter(action="rejected").count(), 1)
        self.assertEqual(case.approvals.count(), case.events.filter(action="review_approved").count())
        self.assertLessEqual(case.approvals.count(), 1)
        self.assertTrue(any(result == (True, "REJECTED") for result in results))

    def test_cancel_racing_approval_never_reopens_case(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        U = get_user_model()
        owner = U.objects.create_user(username="s1race_cancel_subject")
        reviewer = U.objects.create_user(username="s1race_cancel_reviewer", is_staff=True)
        other = U.objects.create_user(username="s1race_cancel_second", is_staff=True)
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=owner, requester=owner,
            quarantine_until=timezone.now() + timedelta(hours=24),
            expires_at=timezone.now() + timedelta(hours=72),
            channel_verified_at=timezone.now(),
        )
        case.quarantine_until = case.created_at + timedelta(hours=24)
        case.expires_at = case.created_at + timedelta(hours=72)
        case.save(update_fields=["quarantine_until", "expires_at"])
        instant = case.quarantine_until + timedelta(seconds=1)
        barrier = Barrier(2)

        def worker(cancel):
            close_old_connections()
            try:
                actor = U.objects.get(pk=owner.pk if cancel else reviewer.pk)
                barrier.wait(timeout=10)
                if cancel:
                    return cancel_recovery_case(case_id=case.pk, actor=actor)
                return record_review(
                    case_id=case.pk, reviewer=actor, approve=True, now=instant
                )
            finally:
                connection.close()

        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=(reviewer.pk, other.pk)):
            with ThreadPoolExecutor(max_workers=2) as executor:
                first = executor.submit(worker, False)
                second = executor.submit(worker, True)
                results = [first.result(timeout=30), second.result(timeout=30)]
        case.refresh_from_db()
        self.assertEqual(case.status, MfaAdministrativeRecoveryCase.Status.CANCELLED)
        self.assertEqual(case.events.filter(action="cancelled").count(), 1)
        self.assertEqual(case.approvals.count(),
                         case.events.filter(action="review_approved").count())
        self.assertLessEqual(case.approvals.count(), 1)
        self.assertIn((True, "CASE_CANCELLED"), results)
