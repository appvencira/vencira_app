from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings

from .mfa_admin_recovery_service import open_recovery_case
from .models import MfaAdministrativeRecoveryCase, UserMfaState


@override_settings(VENCIRA_MFA_RECOVERY_OPENING_TEST_ONLY=True)
class RecoveryOpeningTests(TestCase):
    def test_open_and_duplicate(self):
        user = get_user_model().objects.create_user("opening_fixture")
        state = UserMfaState.objects.create(user=user, enabled=True, encrypted_totp_secret="fixture")
        case_id, reason = open_recovery_case(subject_id=user.pk, requester=user)
        self.assertEqual(reason, "CASE_OPENED_RESTRICTED")
        self.assertTrue(MfaAdministrativeRecoveryCase.objects.filter(pk=case_id).exists())
        state.refresh_from_db()
        self.assertEqual(state.session_epoch, 1)
        self.assertEqual(open_recovery_case(subject_id=user.pk, requester=user)[1], "CASE_ALREADY_PENDING")

    def test_inactive_factor_rejected(self):
        user = get_user_model().objects.create_user("inactive_fixture")
        UserMfaState.objects.create(user=user, enabled=False, encrypted_totp_secret="")
        self.assertEqual(open_recovery_case(subject_id=user.pk, requester=user)[1], "ACTIVE_MFA_REQUIRED")
        self.assertFalse(MfaAdministrativeRecoveryCase.objects.filter(subject=user).exists())
