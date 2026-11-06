"""G14-E1C: isolated PG17 transaction/savepoint semantics for MFA proof.

Tests only: there is no session creation or operational authentication route.
"""
from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, transaction
from django.test import TransactionTestCase
from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from .g14_e1_locked_mfa_verifier import verify_candidate_password_and_totp
from .models import MobileDeviceSession


class G14E1CProofRollbackPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL transaction semantics required")
        self.user = get_user_model().objects.create_user(
            username="g14e1c-rollback", password="synthetic-rollback-password",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=11,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )
        self.timestamp = 300000
        self.good = totp_at(self.secret, self.timestamp)

    def proof(self, code):
        return verify_candidate_password_and_totp(
            username=self.user.username,
            password="synthetic-rollback-password",
            code=code, keys=self.keys, timestamp=self.timestamp,
        )

    def assert_no_session(self):
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_successful_proof_rolls_back_when_outer_transaction_fails(self):
        with self.assertRaisesRegex(RuntimeError, "synthetic downstream failure"):
            with transaction.atomic():
                self.assertIs(self.proof(self.good), True)
                self.assert_no_session()
                raise RuntimeError("synthetic downstream failure")
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertIs(self.proof(self.good), True)
        self.assert_no_session()

    def test_invalid_code_budget_rolls_back_with_outer_transaction(self):
        wrong = "000000" if self.good != "000000" else "111111"
        with self.assertRaisesRegex(RuntimeError, "synthetic downstream failure"):
            with transaction.atomic():
                self.assertIs(self.proof(wrong), False)
                self.state.refresh_from_db()
                self.assertEqual(self.state.failed_attempts, 1)
                raise RuntimeError("synthetic downstream failure")
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assert_no_session()

    def test_inner_savepoint_rollback_does_not_consume_factor(self):
        with transaction.atomic():
            with self.assertRaisesRegex(RuntimeError, "synthetic savepoint"):
                with transaction.atomic():
                    self.assertIs(self.proof(self.good), True)
                    raise RuntimeError("synthetic savepoint")
            self.state.refresh_from_db()
            self.assertEqual(self.state.last_accepted_counter, -1)
            self.assertIs(self.proof(self.good), True)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)
        self.assert_no_session()
