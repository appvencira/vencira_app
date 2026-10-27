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
