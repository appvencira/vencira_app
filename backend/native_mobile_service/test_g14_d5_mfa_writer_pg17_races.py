"""G14-D5: real PostgreSQL MFA state races, disposable test database only.

No secrets or HTTP routes; all TOTP materials are synthetic and ephemeral.
"""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase

from reminders.mfa_secrets import (
    encrypt_totp_secret, hash_recovery_code,
)
from reminders.mfa_session_revocation import revoke_mfa_sessions
from reminders.mfa_store import consume_recovery_code, consume_totp
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaRecoveryCode, UserMfaState
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session, validate_candidate_access,
)


class G14D5MfaWriterPG17Races(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL row locks required")
        self.user = get_user_model().objects.create_user(
            username="g14-d5-pg17-actor",
            password="synthetic-d5-never-operational",
        )
        self.keyring = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=4,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keyring,
            ),
        )

    def _race(self, action):
        ready = Barrier(3)

        def worker():
            connections.close_all()
            try:
                ready.wait(timeout=15)
                return action()
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            left = pool.submit(worker)
            right = pool.submit(worker)
            ready.wait(timeout=15)
            return left.result(timeout=45), right.result(timeout=45)

    def test_parallel_same_totp_has_exactly_one_acceptance(self):
        code = totp_at(self.secret, 300000)
        results = self._race(lambda: consume_totp(
            self.user.pk, code, keys=self.keyring, timestamp=300000,
        ))
        self.assertEqual(sorted(results), [False, True])
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)

    def test_parallel_same_recovery_code_has_exactly_one_acceptance(self):
        code = "A" * 32
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code(code),
        )
        results = self._race(
            lambda: consume_recovery_code(self.user.pk, code),
        )
        self.assertEqual(sorted(results), [False, True])
        self.assertFalse(UserMfaRecoveryCode.objects.filter(
            state=self.state,
        ).exists())

    def test_epoch_revocation_invalidates_mfa_candidate_access(self):
        access, _ = issue_verified_candidate_session(
            user_id=self.user.pk, verified_mfa=True,
            mfa_epoch=4, expected_generation=0,
        )
        self.assertEqual(validate_candidate_access(access).pk, self.user.pk)

        results = self._race(
            lambda: revoke_mfa_sessions(user_id=self.user.pk),
        )
        self.assertEqual(results, (
            (True, "MFA_SESSIONS_REVOKED"),
            (True, "MFA_SESSIONS_REVOKED"),
        ))
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 6)
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(access)
