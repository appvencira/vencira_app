"""Native MFA challenge single-use race on a disposable PG17 DB only."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState

from .login_rules import (
    NativeLoginLabDenied, begin_native_login_lab, finish_native_mfa_lab,
)
from .models import MobileDeviceSessionLab, MobileLoginChallengeLab


class ChallengeRacePG17Tests(TransactionTestCase):
    def test_parallel_mfa_completion_issues_at_most_one_device(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL row locks required")
        password = "PG17SyntheticChallengePassword!2026"
        user = get_user_model().objects.create_user(
            username="n1-pg17-password-challenge",
            password=password,
        )
        key = Fernet.generate_key().decode("ascii")
        secret = generate_secret()
        UserMfaState.objects.create(
            user=user, enabled=True, session_epoch=3,
            encrypted_totp_secret=encrypt_totp_secret(
                secret, user_id=user.pk, keys=[key],
            ),
        )
        mode, challenge = begin_native_login_lab(user.username, password)
        self.assertEqual(mode, "mfa")
        code = totp_at(secret, int(timezone.now().timestamp()))
        start = Barrier(3)

        def contender():
            # A thread may own a reusable Django connection (CONN_MAX_AGE>0).
            # Explicitly close it even on rejection, avoiding leaked PG17
            # sessions that prevent Django from dropping its disposable DB.
            connections.close_all()
            try:
                start.wait(timeout=10)
                return ("issued", finish_native_mfa_lab(challenge, code))
            except NativeLoginLabDenied:
                return ("denied", None)
            finally:
                connections.close_all()

        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            with ThreadPoolExecutor(max_workers=2) as pool:
                tasks = [pool.submit(contender) for _ in range(2)]
                start.wait(timeout=10)
                results = [task.result(timeout=25) for task in tasks]

        self.assertEqual(
            sorted(mode for mode, _ in results),
            ["denied", "issued"],
        )
        self.assertEqual(MobileDeviceSessionLab.objects.count(), 1)
        self.assertIsNotNone(
            MobileLoginChallengeLab.objects.get().consumed_at,
        )
