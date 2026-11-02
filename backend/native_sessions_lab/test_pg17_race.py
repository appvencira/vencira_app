"""PostgreSQL 17 row-lock race rehearsal, disposable database ONLY."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase
from .models import MobileDeviceSessionLab
from .session_rules import (
    SessionLabDenied, issue_verified_session, rotate_refresh,
    validate_access, revoke_all_devices_for_user_lab,
)


class RefreshRacePG17Tests(TransactionTestCase):
    def test_two_parallel_refreshes_cannot_both_succeed(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires true PostgreSQL row locks")
        user = get_user_model().objects.create_user(
            username="n1-pg17-locked-test",
            password="NotAProductionPassword!2026",
        )
        _, refresh = issue_verified_session(
            user=user, verified_mfa=False, mfa_epoch=None)
        start = Barrier(3)

        def contender():
            # A thread may own a reusable Django connection (CONN_MAX_AGE>0).
            # Explicitly close it even on rejection, avoiding leaked PG17
            # sessions that prevent Django from dropping its disposable DB.
            connections.close_all()
            try:
                start.wait(timeout=10)
                return ("issued", rotate_refresh(refresh))
            except SessionLabDenied:
                return ("denied", None)
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(contender) for _ in range(2)]
            start.wait(timeout=10)
            results = [future.result(timeout=20) for future in futures]

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
            sorted(item[0] for item in results),
            ["denied", "issued"],
        )
        row = MobileDeviceSessionLab.objects.get()
        self.assertEqual(row.generation, 1)
        # The second request used an already consumed token. It must revoke
        # the device, including the just-issued access credential.
        self.assertIsNotNone(row.revoked_at)
        success = next(item[1] for item in results if item[0] == "issued")
        with self.assertRaises(SessionLabDenied):
            validate_access(success[0])

    def test_global_revoke_race_with_refresh_remains_revoked(self):
        if connection.vendor != "postgresql":
            self.skipTest("Requires PostgreSQL row locking")
        user = get_user_model().objects.create_user(
            username="n1-pg17-revoke-race",
            password="SyntheticRowLockOnly-2026!",
        )
        access, refresh = issue_verified_session(
            user=user, verified_mfa=False, mfa_epoch=None)
        start = Barrier(3)

        def do_refresh():
            connections.close_all()
            try:
                start.wait(timeout=10)
                return rotate_refresh(refresh)
            except SessionLabDenied:
                return None
            finally:
                connections.close_all()

        def do_revoke():
            connections.close_all()
            try:
                start.wait(timeout=10)
                return revoke_all_devices_for_user_lab(user_id=user.pk)
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(do_refresh)
            b = pool.submit(do_revoke)
            start.wait(timeout=10)
            refreshed = a.result(timeout=20)
            revoked_count = b.result(timeout=20)

        self.assertEqual(revoked_count, 1)
        self.assertIsNotNone(MobileDeviceSessionLab.objects.get().revoked_at)
        with self.assertRaises(SessionLabDenied):
            validate_access(access)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh)
        if refreshed is not None:
            with self.assertRaises(SessionLabDenied):
                validate_access(refreshed[0])
            with self.assertRaises(SessionLabDenied):
                rotate_refresh(refreshed[1])

        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)
