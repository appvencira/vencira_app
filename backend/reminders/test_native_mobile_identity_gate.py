"""Isolated tests for the future mobile identity predicate.

No bearer endpoint is registered; all state lookups are mocked.
"""
from types import SimpleNamespace
from unittest.mock import patch, MagicMock

from django.test import SimpleTestCase

from .native_mobile_identity_gate import (
    MobileIdentityDenied, require_mobile_identity_gate,
    mobile_credential_version,
)


class NativeIdentityGateTests(SimpleTestCase):
    def setUp(self):
        self.hash = "a" * 64
        self.user = SimpleNamespace(
            pk=37, is_active=True, is_authenticated=True,
            get_session_auth_hash=lambda: self.hash,
        )
        self.mfa = None
        self.has_pending = False
        self.has_history = False

    def invoke(self, verified=False, epoch=None, auth_hash=None):
        return require_mobile_identity_gate(
            user=self.user,
            verified_mfa=verified,
            asserted_mfa_epoch=epoch,
            asserted_credential_version=(mobile_credential_version(self.user)
                if auth_hash is None else auth_hash),
        )

    def mock_queries(self):
        mfa_queryset = MagicMock()
        mfa_queryset.first.return_value = self.mfa
        recovery_queryset = MagicMock()
        recovery_queryset.filter.return_value.exists.return_value = self.has_pending
        recovery_queryset.exists.return_value = self.has_history
        mfa_patch = patch(
            "reminders.native_mobile_identity_gate.UserMfaState.objects.filter",
            return_value=mfa_queryset,
        )
        recovery_patch = patch(
            "reminders.native_mobile_identity_gate.MfaAdministrativeRecoveryCase.objects.filter",
            return_value=recovery_queryset,
        )
        mfa_patch.start()
        recovery_patch.start()
        self.addCleanup(mfa_patch.stop)
        self.addCleanup(recovery_patch.stop)

    def test_non_mfa_user_with_valid_auth_version(self):
        self.mock_queries()
        self.assertIs(self.invoke(), self.user)

    def test_password_change_or_invalid_version_denied(self):
        self.mock_queries()
        for token_hash in ("b" * 64, "", "not-64-chars"):
            with self.subTest(hash_length=len(token_hash)):
                with self.assertRaises(MobileIdentityDenied):
                    self.invoke(auth_hash=token_hash)
        previous_version = mobile_credential_version(self.user)
        self.hash = "b" * 64
        with self.assertRaises(MobileIdentityDenied):
            self.invoke(auth_hash=previous_version)

    def test_mobile_version_is_not_django_session_hash(self):
        from django.utils.crypto import salted_hmac
        expected = salted_hmac(
            'vencira.mobile.credential-version.v1',
            self.user.get_session_auth_hash(), algorithm='sha256',
        ).hexdigest()
        self.assertEqual(mobile_credential_version(self.user), expected)
        self.assertNotEqual(mobile_credential_version(self.user), self.hash)
        self.assertEqual(len(mobile_credential_version(self.user)), 64)

    def test_mfa_requires_matching_current_epoch(self):
        self.mfa = SimpleNamespace(enabled=True, session_epoch=8)
        self.mock_queries()
        self.assertIs(self.invoke(verified=True, epoch=8), self.user)
        for verified, epoch in [(False, 8), (True, 7), (True, None)]:
            with self.subTest(verified=verified, epoch=epoch):
                with self.assertRaises(MobileIdentityDenied):
                    self.invoke(verified=verified, epoch=epoch)

    def test_pending_recovery_denied_even_with_mfa(self):
        self.mfa = SimpleNamespace(enabled=True, session_epoch=8)
        self.has_pending = True
        self.has_history = True
        self.mock_queries()
        with self.assertRaises(MobileIdentityDenied):
            self.invoke(verified=True, epoch=8)

    def test_disabled_mfa_and_recovery_history_denied(self):
        self.mfa = SimpleNamespace(enabled=False, session_epoch=8)
        self.has_history = True
        self.mock_queries()
        with self.assertRaises(MobileIdentityDenied):
            self.invoke()

    def test_old_mfa_claim_denied_after_factor_disabled(self):
        self.mfa = SimpleNamespace(enabled=False, session_epoch=8)
        self.mock_queries()
        with self.assertRaises(MobileIdentityDenied):
            self.invoke(verified=True, epoch=8)

    def test_invalid_principal_or_claim_types_denied(self):
        self.mock_queries()
        self.user.is_active = False
        with self.assertRaises(MobileIdentityDenied):
            self.invoke()
        self.user.is_active = True
        for verified, epoch in [(1, None), (False, True), (False, -1),
                                (False, "8")]:
            with self.subTest(verified=verified, epoch=epoch):
                with self.assertRaises(MobileIdentityDenied):
                    self.invoke(verified=verified, epoch=epoch)


    def test_missing_mfa_row_with_recovery_history_denied(self):
        self.has_history = True
        self.mock_queries()
        with self.assertRaises(MobileIdentityDenied):
            self.invoke()

    def test_password_lookup_failure_is_not_a_bypass(self):
        self.user.get_session_auth_hash = lambda: 1 / 0
        self.mock_queries()
        with self.assertRaises(MobileIdentityDenied):
            require_mobile_identity_gate(
                user=self.user, verified_mfa=False,
                asserted_mfa_epoch=None, asserted_credential_version="a" * 64,
            )

    def test_recovery_lookup_failure_is_not_a_bypass(self):
        with patch(
            "reminders.native_mobile_identity_gate.MfaAdministrativeRecoveryCase.objects.filter",
            side_effect=RuntimeError("unavailable"),
        ):
            with self.assertRaises(MobileIdentityDenied):
                self.invoke()

    def test_missing_database_state_fails_closed(self):
        with patch(
            "reminders.native_mobile_identity_gate.UserMfaState.objects.filter",
            side_effect=RuntimeError("unavailable"),
        ):
            with self.assertRaises(MobileIdentityDenied):
                self.invoke()
