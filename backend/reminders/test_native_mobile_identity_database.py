"""N1 identity predicate using REAL ORM state in an isolated Django test DB.

No token issuer, public route, persistent migration or release authorization.
Tests execute with both SQLite and temporary PostgreSQL 17 when configured.
"""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from .models import MfaAdministrativeRecoveryCase, UserMfaState
from .native_mobile_identity_gate import (
    MobileIdentityDenied, mobile_credential_version,
    require_mobile_identity_gate,
)


class NativeIdentityDatabaseTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="n1-identity-orm-synthetic",
            password="SyntheticNotARealCredential!2026",
        )

    def _authorize(self, *, mfa=False, epoch=None, version=None):
        return require_mobile_identity_gate(
            user=self.user,
            verified_mfa=mfa,
            asserted_mfa_epoch=epoch,
            asserted_credential_version=(
                mobile_credential_version(self.user)
                if version is None else version
            ),
        )

    def _mfa(self, *, enabled=True, epoch=5):
        return UserMfaState.objects.create(
            user=self.user,
            enabled=enabled,
            session_epoch=epoch,
            encrypted_totp_secret="not-a-real-secret-in-isolated-test",
        )

    def _case(self, *, status=MfaAdministrativeRecoveryCase.Status.PENDING):
        now = timezone.now()
        return MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user,
            requester=self.user,
            status=status,
            quarantine_until=now + timedelta(days=1),
            expires_at=now + timedelta(days=2),
        )

    def test_unprotected_active_user_is_accepted_with_credential_version(self):
        self.assertIs(self._authorize(), self.user)

    def test_password_rotation_rejects_old_credential_version(self):
        old = mobile_credential_version(self.user)
        self.user.set_password("DifferentSyntheticPassword!2026")
        self.user.save(update_fields=["password"])
        self.assertNotEqual(old, mobile_credential_version(self.user))
        with self.assertRaises(MobileIdentityDenied):
            self._authorize(version=old)
        self.assertIs(self._authorize(), self.user)

    def test_real_mfa_state_requires_verified_epoch(self):
        state = self._mfa(epoch=9)
        self.assertIs(self._authorize(mfa=True, epoch=9), self.user)
        for mfa, epoch in [(False, 9), (True, 8), (True, None)]:
            with self.subTest(mfa=mfa, epoch=epoch):
                with self.assertRaises(MobileIdentityDenied):
                    self._authorize(mfa=mfa, epoch=epoch)
        state.session_epoch = 10
        state.save(update_fields=["session_epoch"])
        with self.assertRaises(MobileIdentityDenied):
            self._authorize(mfa=True, epoch=9)
        self.assertIs(self._authorize(mfa=True, epoch=10), self.user)

    def test_pending_recovery_denies_even_correct_mfa_epoch(self):
        self._mfa(enabled=True, epoch=5)
        self._case()
        with self.assertRaises(MobileIdentityDenied):
            self._authorize(mfa=True, epoch=5)

    def test_historical_recovery_and_disabled_mfa_are_denied(self):
        self._mfa(enabled=False, epoch=5)
        self._case(status=MfaAdministrativeRecoveryCase.Status.REJECTED)
        with self.assertRaises(MobileIdentityDenied):
            self._authorize()

    def test_historical_recovery_and_missing_mfa_row_are_denied(self):
        self._case(status=MfaAdministrativeRecoveryCase.Status.CLOSED)
        with self.assertRaises(MobileIdentityDenied):
            self._authorize()

    def test_disabled_user_is_rejected(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(MobileIdentityDenied):
            self._authorize()
