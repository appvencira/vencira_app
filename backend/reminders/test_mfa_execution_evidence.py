from unittest.mock import patch
from django.test import SimpleTestCase, override_settings
from .mfa_admin_recovery_service import inspect_external_execution_evidence


class ExternalEvidenceTests(SimpleTestCase):
    @patch("reminders.mfa_admin_recovery_service.inspect_recovery_preconditions", return_value=(True, "READY"))
    @override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=None)
    def test_missing_provider(self, _inspect):
        self.assertEqual(inspect_external_execution_evidence(case_id="fixture")[1], "EXTERNAL_EXECUTION_VERIFIER_REQUIRED")

    @patch("reminders.mfa_admin_recovery_service.inspect_recovery_preconditions", return_value=(True, "READY"))
    @override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=lambda **kwargs: False)
    def test_negative_provider(self, _inspect):
        self.assertEqual(inspect_external_execution_evidence(case_id="fixture")[1], "EXTERNAL_EXECUTION_EVIDENCE_REJECTED")

    @patch("reminders.mfa_admin_recovery_service.inspect_recovery_preconditions", return_value=(False, "DENIED"))
    def test_policy_denial_precedes_provider(self, _inspect):
        self.assertEqual(inspect_external_execution_evidence(case_id="fixture"), (False, "DENIED"))


from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from cryptography.fernet import Fernet
from .models import MfaAdministrativeRecoveryCase, UserMfaState
from .mfa_admin_recovery_service import prepare_administrative_factor


class RecoveryPreparationDenyTests(TestCase):
    def test_without_external_evidence_active_credentials_unchanged(self):
        subject = get_user_model().objects.create_user("recover_preparation")
        state = UserMfaState.objects.create(
            user=subject, enabled=True, encrypted_totp_secret="active-fixture",
        )
        now = timezone.now()
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=subject, requester=subject,
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=1),
        )
        keys = [Fernet.generate_key().decode("ascii")]
        with override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=None):
            result = prepare_administrative_factor(case_id=case.pk, keys=keys)
        self.assertIsNone(result)
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, "active-fixture")
        self.assertEqual(state.pending_rotation_secret, "")
        self.assertEqual(state.session_epoch, 0)


class AdministrativeConfirmationDenialTests(TestCase):
    def test_wrong_case_and_missing_external_verifier_preserve_credentials(self):
        import uuid
        from .mfa_admin_recovery_service import confirm_administrative_factor
        from .models import UserMfaPendingRotationCode
        subject = get_user_model().objects.create_user("recovery_confirmation_denied")
        state = UserMfaState.objects.create(
            user=subject, enabled=True, encrypted_totp_secret="active-fixture",
            pending_administrative_case_id=uuid.uuid4(),
            pending_rotation_secret="pending-fixture",
            pending_rotation_expires_at=timezone.now() + timedelta(minutes=5),
        )
        now = timezone.now()
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=subject, requester=subject,
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=1),
        )
        with override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=None):
            self.assertIsNone(confirm_administrative_factor(
                case_id=case.pk, new_code="123456", keys=[],
            ))
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, "active-fixture")
        self.assertEqual(state.pending_rotation_secret, "pending-fixture")
        self.assertEqual(UserMfaPendingRotationCode.objects.filter(state=state).count(), 0)


class AdministrativeFinalizationDenialTests(TestCase):
    def test_denied_case_does_not_replace_factor(self):
        import uuid
        from .mfa_admin_recovery_service import finalize_administrative_factor
        subject = get_user_model().objects.create_user("recovery_finalization_denied")
        state = UserMfaState.objects.create(
            user=subject, enabled=True, encrypted_totp_secret="active-fixture",
            pending_administrative_case_id=uuid.uuid4(),
            pending_rotation_secret="staged-fixture",
            pending_rotation_expires_at=timezone.now() + timedelta(minutes=5),
        )
        now = timezone.now()
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=subject, requester=subject,
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=1),
        )
        with override_settings(VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER=None):
            self.assertFalse(finalize_administrative_factor(
                case_id=case.pk, proof_code="A" * 32,
            ))
        state.refresh_from_db()
        case.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, "active-fixture")
        self.assertEqual(state.session_epoch, 0)
        self.assertEqual(case.status, MfaAdministrativeRecoveryCase.Status.PENDING)


class AdministrativeFinalizationLifecycleTests(TestCase):
    def setUp(self):
        from .models import UserMfaRecoveryCode, UserMfaPendingRotationCode
        from .mfa_secrets import hash_recovery_code
        self.subject = get_user_model().objects.create_user("recovery_lifecycle")
        now = timezone.now()
        self.case = MfaAdministrativeRecoveryCase.objects.create(
            subject=self.subject, requester=self.subject,
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=1),
        )
        self.state = UserMfaState.objects.create(
            user=self.subject, enabled=True,
            encrypted_totp_secret="old-encrypted-secret",
            pending_rotation_secret="new-encrypted-secret",
            pending_administrative_case_id=self.case.pk,
            pending_rotation_expires_at=now + timedelta(minutes=5),
        )
        self.code = "A" * 32
        for idx in range(10):
            value = self.code if idx == 0 else "BCDEFGHIJK"[idx] * 32
            UserMfaPendingRotationCode.objects.create(
                state=self.state, code_hash=hash_recovery_code(value),
            )
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code("Z" * 32),
        )

    def test_success_atomic_switch_and_replay_denial(self):
        from .models import UserMfaRecoveryCode, UserMfaPendingRotationCode
        from .mfa_admin_recovery_service import finalize_administrative_factor
        with patch("reminders.mfa_admin_recovery_service.inspect_external_execution_evidence", return_value=(True, "TEST_ONLY")):
            self.assertTrue(finalize_administrative_factor(case_id=self.case.pk, proof_code=self.code))
            self.assertFalse(finalize_administrative_factor(case_id=self.case.pk, proof_code=self.code))
        self.state.refresh_from_db()
        self.case.refresh_from_db()
        self.assertEqual(self.state.encrypted_totp_secret, "new-encrypted-secret")
        self.assertEqual(self.state.session_epoch, 1)
        self.assertIsNone(self.state.pending_administrative_case_id)
        self.assertEqual(self.case.status, MfaAdministrativeRecoveryCase.Status.CLOSED)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=self.state).count(), 10)
        self.assertFalse(UserMfaPendingRotationCode.objects.filter(state=self.state).exists())

    def test_expired_stage_does_not_change_old_factor(self):
        from .mfa_admin_recovery_service import finalize_administrative_factor
        self.state.pending_rotation_expires_at = timezone.now() - timedelta(seconds=1)
        self.state.save(update_fields=["pending_rotation_expires_at"])
        with patch("reminders.mfa_admin_recovery_service.inspect_external_execution_evidence", return_value=(True, "TEST_ONLY")):
            self.assertFalse(finalize_administrative_factor(case_id=self.case.pk, proof_code=self.code))
        self.state.refresh_from_db()
        self.assertEqual(self.state.encrypted_totp_secret, "old-encrypted-secret")
        self.assertEqual(self.state.session_epoch, 0)

    def test_invalid_proof_does_not_change_old_factor(self):
        from .mfa_admin_recovery_service import finalize_administrative_factor
        with patch("reminders.mfa_admin_recovery_service.inspect_external_execution_evidence", return_value=(True, "TEST_ONLY")):
            self.assertFalse(finalize_administrative_factor(case_id=self.case.pk, proof_code="Q" * 32))
        self.state.refresh_from_db()
        self.assertEqual(self.state.encrypted_totp_secret, "old-encrypted-secret")
        self.assertEqual(self.state.session_epoch, 0)

    def test_invalid_custody_proofs_lock_account_after_five_attempts(self):
        from .mfa_admin_recovery_service import finalize_administrative_factor
        with patch(
            "reminders.mfa_admin_recovery_service.inspect_external_execution_evidence",
            return_value=(True, "SYNTHETIC_TEST_ONLY"),
        ):
            for _ in range(5):
                self.assertFalse(finalize_administrative_factor(
                    case_id=self.case.pk, proof_code="Q" * 32,
                ))
            self.assertFalse(finalize_administrative_factor(
                case_id=self.case.pk, proof_code=self.code,
            ))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 5)
        self.assertGreater(self.state.locked_until, timezone.now())
        self.assertEqual(self.state.encrypted_totp_secret, "old-encrypted-secret")
        self.assertEqual(self.state.session_epoch, 0)


class AdministrativeOwnershipIsolationTests(TestCase):
    def test_expired_factor_owned_by_other_case_is_not_overwritten(self):
        import uuid
        from .mfa_admin_recovery_service import prepare_administrative_factor
        user = get_user_model().objects.create_user("recovery_case_isolation")
        previous_case_id = uuid.uuid4()
        state = UserMfaState.objects.create(
            user=user, enabled=True, encrypted_totp_secret="active-unchanged",
            pending_rotation_secret="old-staged-unchanged",
            pending_rotation_expires_at=timezone.now() - timedelta(minutes=1),
            pending_administrative_case_id=previous_case_id,
        )
        now = timezone.now()
        case = MfaAdministrativeRecoveryCase.objects.create(
            subject=user, requester=user,
            quarantine_until=now - timedelta(hours=1),
            expires_at=now + timedelta(hours=1),
        )
        with patch(
            "reminders.mfa_admin_recovery_service.inspect_external_execution_evidence",
            return_value=(True, "SYNTHETIC_ONLY"),
        ):
            result = prepare_administrative_factor(
                case_id=case.pk, keys=[Fernet.generate_key().decode("ascii")],
            )
        self.assertIsNone(result)
        state.refresh_from_db()
        self.assertEqual(state.pending_administrative_case_id, previous_case_id)
        self.assertEqual(state.pending_rotation_secret, "old-staged-unchanged")
        self.assertEqual(state.encrypted_totp_secret, "active-unchanged")

