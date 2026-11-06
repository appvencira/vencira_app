"""G14-B specification tests for issuer evidence evaluation, no credential issuance."""
from dataclasses import replace

from django.test import SimpleTestCase

from .g14_issuance_contract import (
    IssuanceSecurityEvidence, missing_issuance_requirements,
)


class G14IssuancePolicyContractTests(SimpleTestCase):
    def base(self, **overrides):
        base = IssuanceSecurityEvidence(
            account_active=True, credential_version_current=True,
            generation_current=True, mfa_required=False, mfa_verified=False,
            mfa_epoch_current=False, recovery_quarantine_clear=True,
            abuse_budget_allowed=True, audit_ready=True,
        )
        return replace(base, **overrides)

    def test_unverified_mfa_requirement_not_assumed_disabled(self):
        self.assertIn(
            "mfa_requirement_unknown",
            missing_issuance_requirements(self.base(mfa_required=None)),
        )

    def test_enabled_mfa_requires_completed_factor_and_current_epoch(self):
        evidence = self.base(mfa_required=True)
        self.assertIn("mfa_not_verified", missing_issuance_requirements(evidence))
        self.assertIn("mfa_epoch", missing_issuance_requirements(evidence))
        self.assertEqual(
            missing_issuance_requirements(
                replace(evidence, mfa_verified=True, mfa_epoch_current=True),
            ), (),
        )

    def test_non_mfa_account_rejects_mfa_assertion(self):
        self.assertEqual(
            missing_issuance_requirements(self.base(mfa_verified=True)),
            ("unexpected_mfa_assertion",),
        )

    def test_revocation_generation_mismatch_fails(self):
        self.assertIn(
            "generation",
            missing_issuance_requirements(self.base(generation_current=False)),
        )

    def test_changed_password_fails(self):
        self.assertIn(
            "password_version",
            missing_issuance_requirements(
                self.base(credential_version_current=False),
            ),
        )

    def test_recovery_quarantine_fails(self):
        self.assertIn(
            "recovery_quarantine",
            missing_issuance_requirements(
                self.base(recovery_quarantine_clear=False),
            ),
        )

    def test_unavailable_throttle_or_audit_fails(self):
        self.assertEqual(
            missing_issuance_requirements(self.base(
                abuse_budget_allowed=False, audit_ready=False,
            )),
            ("abuse_budget", "audit"),
        )

    def test_inactive_user_fails(self):
        self.assertIn(
            "account",
            missing_issuance_requirements(self.base(account_active=False)),
        )

    def test_invalid_or_missing_evidence_fails_closed(self):
        for evidence in (None, {}, True):
            with self.subTest(evidence=evidence):
                with self.assertRaises(TypeError):
                    missing_issuance_requirements(evidence)
        self.assertIn(
            "account",
            missing_issuance_requirements(self.base(account_active=1)),
        )

    def test_policy_does_not_generate_authorization_or_identity(self):
        self.assertEqual(missing_issuance_requirements(self.base()), ())
        # Empty requirements is NOT an authentication proof and carries no
        # token, session ID, verified password or MFA attestation.
        self.assertIsInstance(missing_issuance_requirements(self.base()), tuple)
