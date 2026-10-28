"""D1.5d: prueba de carrera real sobre PostgreSQL, no SQLite."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.test import TransactionTestCase

from .mfa_secrets import (
    encrypt_totp_secret, generate_recovery_codes, hash_recovery_code,
)
from .mfa_store import consume_recovery_code
from .mfa_totp import generate_secret
from .models import UserMfaRecoveryCode, UserMfaState


class RecoveryConcurrencyTests(TransactionTestCase):
    def test_only_one_simultaneous_consumer_can_succeed(self):
        if connection.vendor != "postgresql":
            self.skipTest("SELECT FOR UPDATE requires PostgreSQL")
        user = get_user_model().objects.create_user(
            username="mfa_race_demo", password="LocalOnlyPassword!2026",
        )
        key = Fernet.generate_key().decode("ascii")
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(
                generate_secret(), user_id=user.pk, keys=[key],
            ),
        )
        code = generate_recovery_codes()[0]
        UserMfaRecoveryCode.objects.create(
            state=state, code_hash=hash_recovery_code(code),
        )
        barrier = Barrier(2)

        def worker():
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                return consume_recovery_code(user.pk, code)
            finally:
                connection.close()

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(worker) for _ in range(2)]
            results = [future.result(timeout=20) for future in futures]

        self.assertEqual(sorted(results), [False, True])
        self.assertFalse(UserMfaRecoveryCode.objects.filter(state=state).exists())
