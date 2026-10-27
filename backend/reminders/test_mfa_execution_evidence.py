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
