"""Native MFA challenge single-use race on a disposable PG17 DB only."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, Event
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState

from . import login_rules as lab_login_module
from .login_rules import (
    NativeLoginLabDenied, begin_native_login_lab, finish_native_mfa_lab,
)
from .models import MobileDeviceSessionLab, MobileLoginChallengeLab
from .session_rules import (
    SessionLabDenied, revoke_all_devices_for_user_lab, validate_access,
)


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

        # Verify worker connections are gone BEFORE Django tears down the DB.
        # The previous batch failed DROP DATABASE with two lingering sessions.
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)

        self.assertEqual(
            sorted(mode for mode, _ in results),
            ["denied", "issued"],
        )
        self.assertEqual(MobileDeviceSessionLab.objects.count(), 1)
        self.assertIsNotNone(
            MobileLoginChallengeLab.objects.get().consumed_at,
        )

    def test_account_revoke_race_with_mfa_finish_never_resurrects(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        password = "SyntheticRevocationRacePassword!2026"
        user = get_user_model().objects.create_user(
            username="n1-mfa-revocation-race",
            password=password,
        )
        key = Fernet.generate_key().decode("ascii")
        secret = generate_secret()
        UserMfaState.objects.create(
            user=user, enabled=True, session_epoch=8,
            encrypted_totp_secret=encrypt_totp_secret(
                secret, user_id=user.pk, keys=[key],
            ),
        )
        mode, challenge = begin_native_login_lab(user.username, password)
        self.assertEqual(mode, "mfa")
        code = totp_at(secret, int(timezone.now().timestamp()))
        start = Barrier(3)

        def finish():
            connections.close_all()
            try:
                start.wait(timeout=10)
                return finish_native_mfa_lab(challenge, code)
            except NativeLoginLabDenied:
                return None
            finally:
                connections.close_all()

        def revoke():
            connections.close_all()
            try:
                start.wait(timeout=10)
                return revoke_all_devices_for_user_lab(user_id=user.pk)
            finally:
                connections.close_all()

        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            with ThreadPoolExecutor(max_workers=2) as pool:
                pending_finish = pool.submit(finish)
                pending_revoke = pool.submit(revoke)
                start.wait(timeout=10)
                tokens = pending_finish.result(timeout=25)
                revoked_count = pending_revoke.result(timeout=25)

        self.assertIn(revoked_count, (0, 1))
        self.assertFalse(
            MobileDeviceSessionLab.objects.filter(revoked_at__isnull=True).exists()
        )
        self.assertIsNotNone(MobileLoginChallengeLab.objects.get().consumed_at)
        with self.assertRaises(NativeLoginLabDenied):
            finish_native_mfa_lab(challenge, code)
        if tokens is not None:
            with self.assertRaises(SessionLabDenied):
                validate_access(tokens[0])

        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)

    def test_revocation_between_password_and_account_lock_denies_login(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        password = "SyntheticEpochBoundaryPassword!2026"
        user = get_user_model().objects.create_user(
            username="n1-pg17-epoch-race",
            password=password,
        )
        ready = Event()
        allow = Event()
        original_generation = lab_login_module.account_generation_lab

        def hold_initial_epoch(user_id):
            generation = original_generation(user_id)
            if not ready.is_set():
                ready.set()
                if not allow.wait(timeout=10):
                    raise RuntimeError("Test synchronisation timed out")
            return generation

        def login_worker():
            connections.close_all()
            try:
                try:
                    return begin_native_login_lab(user.username, password)
                except NativeLoginLabDenied:
                    return None
            finally:
                connections.close_all()

        with patch.object(
            lab_login_module, "account_generation_lab",
            side_effect=hold_initial_epoch,
        ):
            with ThreadPoolExecutor(max_workers=1) as pool:
                pending = pool.submit(login_worker)
                try:
                    self.assertTrue(ready.wait(timeout=10))
                    self.assertEqual(
                        revoke_all_devices_for_user_lab(user_id=user.pk), 0
                    )
                finally:
                    allow.set()
                result = pending.result(timeout=20)

        self.assertIsNone(result)
        self.assertFalse(
            MobileDeviceSessionLab.objects.filter(user_id=user.pk).exists()
        )
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)

    def test_password_rotation_between_authenticate_and_user_lock_denies(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        password = "SyntheticG6OldPassword!2026"
        user = get_user_model().objects.create_user(
            username="n1-g6-password-rotation-race",
            password=password,
        )
        ready = Event()
        proceed = Event()
        original = lab_login_module.account_generation_lab

        def hold_before_lock(user_id):
            generation = original(user_id)
            if not ready.is_set():
                ready.set()
                if not proceed.wait(timeout=10):
                    raise RuntimeError("Synthetic password race synchronisation")
            return generation

        def login_worker():
            connections.close_all()
            try:
                try:
                    return begin_native_login_lab(
                        user.username, password, replace_devices=True,
                    )
                except NativeLoginLabDenied:
                    return None
            finally:
                connections.close_all()

        with patch.object(
            lab_login_module, "account_generation_lab",
            side_effect=hold_before_lock,
        ):
            with ThreadPoolExecutor(max_workers=1) as pool:
                pending = pool.submit(login_worker)
                try:
                    self.assertTrue(ready.wait(timeout=10))
                    user.set_password("SyntheticG6NewPassword!2026")
                    user.save(update_fields=["password"])
                finally:
                    proceed.set()
                result = pending.result(timeout=20)

        self.assertIsNone(result)
        self.assertFalse(
            MobileDeviceSessionLab.objects.filter(user_id=user.pk).exists()
        )
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)
