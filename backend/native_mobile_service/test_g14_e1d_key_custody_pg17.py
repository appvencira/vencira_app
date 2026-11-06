"""G14-E1D disposable PG17 negative key-custody and account-state tests.

This test module never issues tokens, opens HTTP routes, or uses real keys.
"""
from datetime import timedelta

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from .g14_e1_locked_mfa_verifier import (
    CandidateMfaDenied, verify_candidate_password_and_totp,
)
from .models import MobileDeviceSession


class G14E1DKeyCustodyPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL isolation required")
        self.user = get_user_model().objects.create_user(
            username="e1d-synthetic", password="e1d-test-only",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=5,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )
        self.timestamp = 300000
        self.code = totp_at(self.secret, self.timestamp)

    def verify(self, keys=None):
        return verify_candidate_password_and_totp(
            username=self.user.username,
            password="e1d-test-only", code=self.code,
            keys=self.keys if keys is None else keys,
            timestamp=self.timestamp,
        )

    def assert_untouched(self):
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertEqual(self.state.session_epoch, 5)
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_missing_keyring_denied_without_consumption(self):
        with self.assertRaises(CandidateMfaDenied):
            self.verify(keys=[])
        self.assert_untouched()

    def test_unknown_key_cannot_decrypt_or_consume_factor(self):
        foreign = [Fernet.generate_key().decode("ascii")]
        with self.assertRaises(CandidateMfaDenied) as denied:
            self.verify(keys=foreign)
        self.assertIsNone(denied.exception.__cause__)
        self.assert_untouched()
        self.assertIs(self.verify(), True)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_malformed_key_denied_without_details_or_consumption(self):
        with self.assertRaises(CandidateMfaDenied) as denied:
            self.verify(keys=["not-a-valid-fernet-key"])
        self.assertIsNone(denied.exception.__cause__)
        self.assert_untouched()

    def test_inactive_account_denied_without_factor_consumption(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(CandidateMfaDenied):
            self.verify()
        self.assert_untouched()

    def test_pending_recovery_denied_even_with_valid_factor(self):
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        with self.assertRaises(CandidateMfaDenied):
            self.verify()
        self.assert_untouched()
