"""Read-only readiness report never prints keys or grants approval."""
from io import StringIO
from unittest.mock import patch

from django.core.management import call_command
from django.test import TestCase, override_settings

from .management.commands.mfa_readiness import readiness_report


class MfaReadinessTests(TestCase):
    @override_settings(VENCIRA_MFA_ENROLLMENT_ENABLED=False)
    def test_missing_keys_fail_closed_without_exposure(self):
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": "sensitive-but-invalid"}):
            output = StringIO()
            call_command("mfa_readiness", stdout=output)
        self.assertIn("MFA_KEYRING_VALID=PENDING", output.getvalue())
        self.assertIn("MFA_RELEASE_AUTHORIZED=NO", output.getvalue())
        self.assertNotIn("sensitive-but-invalid", output.getvalue())

    @override_settings(VENCIRA_MFA_ENROLLMENT_ENABLED=True)
    def test_enabled_flag_is_reported_not_changed(self):
        report = readiness_report()
        self.assertFalse(report["enrollment_flag_off"])
        self.assertTrue(report["mfa_migrations_applied"])

    def test_readiness_rejects_missing_final_migration(self):
        from django.db.migrations.recorder import MigrationRecorder
        from .management.commands.mfa_rollback_guard import REQUIRED
        incomplete = {("reminders", migration) for migration in REQUIRED[:-1]}
        with patch.object(MigrationRecorder, "has_table", return_value=True), \
                patch.object(MigrationRecorder, "applied_migrations", return_value=incomplete):
            report = readiness_report()
        self.assertFalse(report["mfa_migrations_applied"])
        self.assertIsNone(report["active_accounts"])
