"""G14-E1B: PG17-only MFA proof concurrency/denial-budget regressions.

No session issuance, endpoints, real identities or live persistence.
"""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from .g14_e1_locked_mfa_verifier import (
    CandidateMfaDenied, verify_candidate_password_and_totp,
)
from .models import MobileDeviceSession


class G14E1BConcurrencyPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PG17 row-level locks required")
        self.password = "g14e1b-synthetic-password"
        self.user = get_user_model().objects.create_user(
            username="g14-e1b-actor", password=self.password,
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=7,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )
        self.timestamp = 300000
        self.good_code = totp_at(self.secret, self.timestamp)

    def verify(self, *, code=None, password=None):
        return verify_candidate_password_and_totp(
            username=self.user.username,
            password=self.password if password is None else password,
            code=self.good_code if code is None else code,
            keys=self.keys, timestamp=self.timestamp,
        )

    def test_same_totp_concurrent_accepts_once_no_sessions(self):
        gate = Barrier(3)

        def attempt():
            connections.close_all()
            try:
                gate.wait(timeout=15)
                return self.verify()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            left = pool.submit(attempt)
            right = pool.submit(attempt)
            gate.wait(timeout=15)
            results = [left.result(timeout=45), right.result(timeout=45)]
        self.assertEqual(sorted(results), [False, True])
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_bad_totp_persists_attempt_budget(self):
        bad = "000000" if self.good_code != "000000" else "111111"
        self.assertFalse(self.verify(code=bad))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 1)
        self.assertIsNotNone(self.state.attempts_started_at)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_five_bad_totp_attempts_lock_and_deny_good_code(self):
        bad = "000000" if self.good_code != "000000" else "111111"
        for _ in range(5):
            self.assertFalse(self.verify(code=bad))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 5)
        self.assertGreater(self.state.locked_until, timezone.now())
        self.assertFalse(self.verify())
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_password_does_not_increment_totp_budget(self):
        with self.assertRaises(CandidateMfaDenied):
            self.verify(password="incorrect")
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())
