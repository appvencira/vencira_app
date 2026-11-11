"""D20 release-readiness policy tests; no tokens, network, DB or rollout."""
from dataclasses import replace

from django.test import SimpleTestCase, override_settings

from .native_operational_issuer_gate import (
    NativeIssuerUnavailable,
    NativeOperationalReadiness,
    assert_operational_issuer_unavailable,
    operational_readiness_missing,
)


class NativeOperationalIssuerGateTests(SimpleTestCase):
    def base(self, **overrides):
        context = NativeOperationalReadiness(
            environment="production",
            service_installed=True,
            bearer_enabled=True,
            issuer_authorized=True,
            mobile_routes_authorized=True,
            production_key_custody_verified=True,
            mfa_trusted_issuer_verified=True,
            account_recovery_verified=True,
            abuse_and_audit_verified=True,
            mobile_device_https_verified=True,
        )
        return replace(context, **overrides)

    def test_every_missing_control_fails(self):
        self.assertEqual(operational_readiness_missing(self.base()), ())
        for field in (
            "service_installed", "bearer_enabled", "issuer_authorized",
            "mobile_routes_authorized", "production_key_custody_verified",
            "mfa_trusted_issuer_verified", "account_recovery_verified",
            "abuse_and_audit_verified", "mobile_device_https_verified",
        ):
            with self.subTest(field=field):
                failures = operational_readiness_missing(
                    self.base(**{field: False})
                )
                self.assertTrue(failures)

    def test_nonproduction_and_unknown_evidence_are_denied(self):
        self.assertIn(
            "production_environment",
            operational_readiness_missing(self.base(environment="test")),
        )
        self.assertIn(
            "production_environment",
            operational_readiness_missing(self.base(environment="development")),
        )
        self.assertIn(
            "issuer_authorized",
            operational_readiness_missing(self.base(issuer_authorized=None)),
        )
        self.assertIn(
            "issuer_authorized",
            operational_readiness_missing(self.base(issuer_authorized=1)),
        )

    def test_request_supplied_evidence_cannot_be_accepted(self):
        for value in (None, {}, True, object()):
            with self.subTest(value=type(value).__name__):
                with self.assertRaises(TypeError):
                    operational_readiness_missing(value)

    def test_all_true_evidence_is_never_a_credential(self):
        self.assertEqual(operational_readiness_missing(self.base()), ())
        self.assertIsInstance(operational_readiness_missing(self.base()), tuple)
        self.assertFalse(hasattr(self.base(), "access"))
        self.assertFalse(hasattr(self.base(), "refresh"))

    @override_settings(
        VENCIRA_ENV="production",
        VENCIRA_NATIVE_SERVICE_CANDIDATE=True,
        VENCIRA_NATIVE_BEARER_ENABLED=True,
    )
    def test_even_all_flags_true_never_activates_issuer(self):
        with self.assertRaises(NativeIssuerUnavailable):
            assert_operational_issuer_unavailable()

    @override_settings(
        VENCIRA_ENV="test",
        VENCIRA_NATIVE_SERVICE_CANDIDATE=True,
        VENCIRA_NATIVE_BEARER_ENABLED=True,
    )
    def test_lab_flags_never_turn_into_operational_issuance(self):
        with self.assertRaises(NativeIssuerUnavailable):
            assert_operational_issuer_unavailable()

    @override_settings(
        VENCIRA_ENV="production",
        VENCIRA_NATIVE_SERVICE_CANDIDATE=False,
        VENCIRA_NATIVE_BEARER_ENABLED=False,
    )
    def test_default_production_flags_block_issuance(self):
        with self.assertRaises(NativeIssuerUnavailable):
            assert_operational_issuer_unavailable()
