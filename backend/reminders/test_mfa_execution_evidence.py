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
