"""G14-E1: synthetic PG17 verification only, no token issuer."""
from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase
from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState, MfaAdministrativeRecoveryCase
from django.utils import timezone
from datetime import timedelta
from .g14_e1_locked_mfa_verifier import (
    CandidateMfaDenied, verify_candidate_password_and_totp,
)
from .models import MobileDeviceSession


class G14E1LockedMfaVerifierPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL row lock test only")
        self.user = get_user_model().objects.create_user(
            username="g14-e1-actor", password="synthetic-e1-password",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=6,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )
        self.timestamp = 300000

    def check(self, password="synthetic-e1-password", code=None):
        return verify_candidate_password_and_totp(
            username=self.user.username, password=password,
            code=code if code is not None else totp_at(self.secret, self.timestamp),
            keys=self.keys, timestamp=self.timestamp,
        )

    def test_verified_factor_consumes_once_without_session(self):
        self.assertIs(self.check(), True)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(self.check())
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_password_does_not_consume_factor(self):
        with self.assertRaises(CandidateMfaDenied):
            self.check(password="wrong-password")
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_factor_fails_without_session(self):
        correct = totp_at(self.secret, self.timestamp)
        wrong = "000000" if correct != "000000" else "111111"
        self.assertFalse(self.check(code=wrong))
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_pending_administrative_recovery_blocks_factor(self):
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        with self.assertRaises(CandidateMfaDenied):
            self.check()
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_input_denies_without_session(self):
        with self.assertRaises(CandidateMfaDenied):
            self.check(code="123")
        self.assertFalse(MobileDeviceSession.objects.exists())
