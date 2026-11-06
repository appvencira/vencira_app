"""G14-D9 isolated negative verification checks for administrative MFA recovery.

No production endpoint; only synthetic identities in disposable test databases.
"""
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from reminders.mfa_admin_recovery_service import open_recovery_case


class G14D9RecoveryGuards(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PG17 isolation required")
        self.user = get_user_model().objects.create_user(
            username="g14d9-synthetic", password="not-a-real-secret",
        )
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True,
            encrypted_totp_secret="synthetic-unused",
            session_epoch=7,
        )

    def assert_unchanged(self):
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 7)
        self.assertFalse(MfaAdministrativeRecoveryCase.objects.filter(
            subject_id=self.user.pk,
        ).exists())

    @override_settings(VENCIRA_MFA_RECOVERY_IDENTITY_VERIFIER=None)
    def test_missing_verifier_fails_closed(self):
        case, reason = open_recovery_case(
            subject_id=self.user.pk, requester=self.user,
        )
        self.assertIsNone(case)
        self.assertEqual(reason, "INDEPENDENT_IDENTITY_VERIFIER_REQUIRED")
        self.assert_unchanged()

    @override_settings(
        VENCIRA_MFA_RECOVERY_IDENTITY_VERIFIER=lambda **kwargs: False,
    )
    def test_negative_verifier_fails_closed(self):
        case, reason = open_recovery_case(
            subject_id=self.user.pk, requester=self.user,
        )
        self.assertIsNone(case)
        self.assertEqual(reason, "INDEPENDENT_IDENTITY_NOT_VERIFIED")
        self.assert_unchanged()
