"""PG17 test-only administrative factor recovery finalization races."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_admin_recovery_service import (
    cancel_recovery_case, expire_recovery_case,
    finalize_administrative_factor, record_review,
)
from reminders.mfa_secrets import encrypt_totp_secret, hash_recovery_code
from reminders.mfa_totp import generate_secret
from reminders.models import (
    MfaAdministrativeRecoveryApproval, MfaAdministrativeRecoveryCase,
    UserMfaPendingRotationCode, UserMfaState,
)


class G14D9CAdminFinalizePG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL-only race")
        User = get_user_model()
        self.subject = User.objects.create_user(username="g14d9c-subject")
        self.reviewers = [
            User.objects.create_user(username=f"g14d9c-review-{i}", is_staff=True)
            for i in range(2)
        ]
        now = timezone.now()
        self.case = MfaAdministrativeRecoveryCase.objects.create(
            subject=self.subject, requester=self.subject,
            channel_verified_at=now - timedelta(hours=24),
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(minutes=40),
        )
        MfaAdministrativeRecoveryCase.objects.filter(pk=self.case.pk).update(
            created_at=now - timedelta(hours=25),
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.original = encrypt_totp_secret(
            generate_secret(), user_id=self.subject.pk, keys=self.keys,
        )
        self.prepared = encrypt_totp_secret(
            generate_secret(), user_id=self.subject.pk, keys=self.keys,
        )
        self.state = UserMfaState.objects.create(
            user=self.subject, enabled=True, session_epoch=9,
            encrypted_totp_secret=self.original,
            pending_rotation_secret=self.prepared,
            pending_rotation_expires_at=now + timedelta(minutes=10),
            pending_administrative_case_id=self.case.pk,
        )
        self.proof = "A" * 32
        UserMfaPendingRotationCode.objects.bulk_create([
            UserMfaPendingRotationCode(
                state=self.state,
                code_hash=hash_recovery_code(self.proof) if i == 0 else "synthetic-unused",
            ) for i in range(10)
        ])
        for reviewer in self.reviewers:
            MfaAdministrativeRecoveryApproval.objects.create(
                case=self.case, reviewer=reviewer,
                expires_at=now + timedelta(minutes=20),
            )

    def race(self, left, right):
        barrier = Barrier(3)

        def run(action):
            connections.close_all()
            try:
                barrier.wait(timeout=15)
                return action()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(run, left)
            b = pool.submit(run, right)
            barrier.wait(timeout=15)
            return a.result(timeout=45), b.result(timeout=45)

    @override_settings(
        VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=lambda **kwargs: True,
    )
    def test_cancel_vs_finalization_cannot_both_succeed(self):
        # Verifier is a disposable fixture, not independent identity evidence.
        finalized, (cancelled, reason) = self.race(
            lambda: finalize_administrative_factor(
                case_id=self.case.pk, proof_code=self.proof,
            ),
            lambda: cancel_recovery_case(
                case_id=self.case.pk, actor=self.subject,
            ),
        )
        self.assertNotEqual(finalized, cancelled)
        self.case.refresh_from_db()
        self.state.refresh_from_db()
        if finalized:
            self.assertEqual(self.case.status, self.case.Status.CLOSED)
            self.assertEqual(self.state.encrypted_totp_secret, self.prepared)
            self.assertEqual(self.state.session_epoch, 10)
            self.assertEqual(reason, "CASE_NOT_PENDING")
        else:
            self.assertEqual(self.case.status, self.case.Status.CANCELLED)
            self.assertEqual(self.state.encrypted_totp_secret, self.original)
            self.assertEqual(self.state.session_epoch, 9)
            self.assertEqual(reason, "CASE_CANCELLED")

    @override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=None)
    def test_missing_execution_evidence_preserves_factor(self):
        self.assertFalse(finalize_administrative_factor(
            case_id=self.case.pk, proof_code=self.proof,
        ))
        self.case.refresh_from_db()
        self.state.refresh_from_db()
        self.assertEqual(self.case.status, self.case.Status.PENDING)
        self.assertEqual(self.state.encrypted_totp_secret, self.original)
        self.assertEqual(self.state.session_epoch, 9)

    @override_settings(
        VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=lambda **kwargs: True,
    )
    def test_expiry_vs_finalization_cannot_both_succeed(self):
        # A deterministic, future expiry timestamp is supplied only to the
        # isolated expiration worker; the finalizer uses its own clock.
        expiry_time = self.case.expires_at + timedelta(seconds=1)
        finalized, (expired, reason) = self.race(
            lambda: finalize_administrative_factor(
                case_id=self.case.pk, proof_code=self.proof,
            ),
            lambda: expire_recovery_case(
                case_id=self.case.pk, actor=self.reviewers[0],
                now=expiry_time,
            ),
        )
        self.assertNotEqual(finalized, expired)
        self.case.refresh_from_db()
        self.state.refresh_from_db()
        if finalized:
            self.assertEqual(self.case.status, self.case.Status.CLOSED)
            self.assertEqual(self.state.encrypted_totp_secret, self.prepared)
            self.assertEqual(self.state.session_epoch, 10)
            self.assertEqual(reason, "CASE_NOT_PENDING")
        else:
            self.assertEqual(self.case.status, self.case.Status.EXPIRED)
            self.assertEqual(self.state.encrypted_totp_secret, self.original)
            self.assertEqual(self.state.session_epoch, 9)
            self.assertEqual(reason, "CASE_EXPIRED")

    @override_settings(
        VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=lambda **kwargs: True,
    )
    def test_rejection_vs_finalization_cannot_both_succeed(self):
        third_reviewer = get_user_model().objects.create_user(
            username="g14d9d-third-reviewer", is_staff=True,
        )
        roster = tuple(user.pk for user in self.reviewers) + (third_reviewer.pk,)
        with override_settings(VENCIRA_MFA_RECOVERY_REVIEWER_IDS=roster):
            finalized, (rejected, reason) = self.race(
                lambda: finalize_administrative_factor(
                    case_id=self.case.pk, proof_code=self.proof,
                ),
                lambda: record_review(
                    case_id=self.case.pk, reviewer=third_reviewer,
                    approve=False, now=timezone.now(),
                ),
            )
        self.assertNotEqual(finalized, rejected)
        self.case.refresh_from_db()
        self.state.refresh_from_db()
        if finalized:
            self.assertEqual(self.case.status, self.case.Status.CLOSED)
            self.assertEqual(self.state.encrypted_totp_secret, self.prepared)
            self.assertEqual(self.state.session_epoch, 10)
            self.assertEqual(reason, "CASE_NOT_PENDING")
        else:
            self.assertEqual(self.case.status, self.case.Status.REJECTED)
            self.assertEqual(self.state.encrypted_totp_secret, self.original)
            self.assertEqual(self.state.session_epoch, 9)
            self.assertEqual(reason, "REJECTED")
