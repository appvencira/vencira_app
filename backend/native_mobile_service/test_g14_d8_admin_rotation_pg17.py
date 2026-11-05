"""G14-D8: administrative-recovery and factor-rotation PG17 races.

Disposable database and synthetic fixtures only. These tests are about
revocation invariants, not proof of a trusted MFA authentication issuer.
"""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_admin_recovery_service import open_recovery_case
from reminders.mfa_factor_rotation import finalize_factor_rotation
from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_session_revocation import revoke_mfa_sessions
from reminders.mfa_totp import generate_secret
from reminders.models import (
    MfaAdministrativeRecoveryCase, UserMfaPendingRotationCode,
    UserMfaState,
)
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session, validate_candidate_access,
)


class G14D8AdminRotationPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL concurrency required")
        self.user = get_user_model().objects.create_user(
            username="g14-d8-synthetic-user",
            password="synthetic-only-never-operational",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=3,
            encrypted_totp_secret=encrypt_totp_secret(
                generate_secret(), user_id=self.user.pk, keys=self.keys,
            ),
        )

    def run_two(self, left_action, right_action):
        barrier = Barrier(3)

        def worker(action):
            connections.close_all()
            try:
                barrier.wait(timeout=15)
                return action()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            left = pool.submit(worker, left_action)
            right = pool.submit(worker, right_action)
            barrier.wait(timeout=15)
            return left.result(timeout=45), right.result(timeout=45)

    def issue_synthetic_candidate(self):
        return issue_verified_candidate_session(
            user_id=self.user.pk, verified_mfa=True,
            mfa_epoch=3, expected_generation=0,
        )

    def test_final_rotation_vs_epoch_revocation_invalidates_old_access(self):
        access, _ = self.issue_synthetic_candidate()
        self.state.pending_rotation_secret = encrypt_totp_secret(
            generate_secret(), user_id=self.user.pk, keys=self.keys,
        )
        self.state.pending_rotation_expires_at = timezone.now() + timezone.timedelta(minutes=10)
        self.state.save(update_fields=[
            "pending_rotation_secret", "pending_rotation_expires_at",
        ])
        UserMfaPendingRotationCode.objects.bulk_create([
            UserMfaPendingRotationCode(state=self.state, code_hash=f"synthetic-{i}")
            for i in range(10)
        ])

        def finalize():
            with patch("reminders.mfa_secrets.verify_recovery_code", return_value=True):
                return finalize_factor_rotation(
                    user_id=self.user.pk, proof_code="A" * 32, keys=self.keys,
                )

        rotated, revoked = self.run_two(
            finalize, lambda: revoke_mfa_sessions(user_id=self.user.pk),
        )
        self.assertTrue(rotated)
        self.assertEqual(revoked, (True, "MFA_SESSIONS_REVOKED"))
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 5)
        self.assertEqual(self.state.pending_rotation_secret, "")
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(access)

    @override_settings(
        VENCIRA_MFA_RECOVERY_IDENTITY_VERIFIER=lambda **kwargs: True,
    )
    def test_open_admin_recovery_vs_candidate_issuance_never_leaves_valid_access(self):
        # The verifier override is synthetic; no operational identity proof.
        def open_case():
            return open_recovery_case(
                subject_id=self.user.pk, requester=self.user,
            )

        def candidate_issue():
            try:
                return self.issue_synthetic_candidate()
            except MobileTokenDenied:
                return None

        (case_id, reason), pair = self.run_two(open_case, candidate_issue)
        self.assertEqual(reason, "CASE_OPENED_RESTRICTED")
        self.assertIsNotNone(case_id)
        self.assertTrue(MfaAdministrativeRecoveryCase.objects.filter(
            pk=case_id,
            status=MfaAdministrativeRecoveryCase.Status.PENDING,
        ).exists())
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 4)
        if pair is not None:
            with self.assertRaises(MobileTokenDenied):
                validate_candidate_access(pair[0])
