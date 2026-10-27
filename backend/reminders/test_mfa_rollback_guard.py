"""D1.5r rollback downgrade gate using only ephemeral test databases."""
from io import StringIO
from django.contrib.auth import get_user_model
from django.core.management import call_command, CommandError
from django.test import TestCase
from unittest.mock import patch

from .management.commands.mfa_rollback_guard import check_candidate
from .models import UserMfaState


class MfaRollbackGuardTests(TestCase):
    def test_no_enabled_accounts_allows_candidate_without_factor(self):
        allowed, reason = check_candidate(candidate_enforces_mfa=False)
        self.assertTrue(allowed)
        self.assertEqual(reason, "NO_ACTIVE_MFA_ACCOUNTS")

    def test_enabled_account_blocks_candidate_without_factor(self):
        user = get_user_model().objects.create_user(
            username="rollback_gate_demo", password="LocalOnlyPassword!2026")
        UserMfaState.objects.create(
            user=user, encrypted_totp_secret="test-only", enabled=True)
        allowed, reason = check_candidate(candidate_enforces_mfa=False)
        self.assertFalse(allowed)
        self.assertEqual(reason, "MFA_DOWNGRADE_FORBIDDEN")
        with self.assertRaises(CommandError):
            call_command("mfa_rollback_guard", "--candidate-lacks-mfa",
                         stdout=StringIO())
        self.assertTrue(check_candidate(candidate_enforces_mfa=True)[0])

    def test_unknown_schema_fails_closed(self):
        with patch(
            "reminders.management.commands.mfa_rollback_guard."
            "MigrationRecorder.has_table", return_value=False,
        ):
            allowed, reason = check_candidate(candidate_enforces_mfa=True)
        self.assertFalse(allowed)
        self.assertEqual(reason, "UNKNOWN_SCHEMA")
