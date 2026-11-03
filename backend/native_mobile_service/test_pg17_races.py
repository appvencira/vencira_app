"""Concurrency invariants for G4 candidate; disposable PostgreSQL17 only."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.contrib.auth import get_user_model
from django.db import connection, connections
from django.test import TransactionTestCase

from .models import MobileAccountFence, MobileDeviceSession
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session,
    revoke_all_candidate_devices, rotate_candidate_refresh,
    validate_candidate_access,
)


class CandidateRacePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL17 row locks required")
        self.user = get_user_model().objects.create_user(
            username="g4-pg17-race-candidate",
            password="SyntheticNativeG4RacePassword-2026",
        )

    def test_parallel_refresh_same_secret_has_one_winner_then_revokes(self):
        old_access, refresh = issue_verified_candidate_session(
            user_id=self.user.pk, verified_mfa=False, mfa_epoch=None,
            expected_generation=0,
        )
        start = Barrier(3)

        def contender():
            connections.close_all()
            try:
                start.wait(timeout=12)
                try:
                    return ("issued", rotate_candidate_refresh(refresh))
                except MobileTokenDenied:
                    return ("denied", None)
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(contender)
            second = pool.submit(contender)
            start.wait(timeout=12)
            left = first.result(timeout=35)
            right = second.result(timeout=35)

        self.assertEqual(
            sorted([left[0], right[0]]), ["denied", "issued"],
        )
        winner = left[1] if left[0] == "issued" else right[1]
        self.assertIsNotNone(MobileDeviceSession.objects.get().revoked_at)
        for access in (old_access, winner[0]):
            with self.assertRaises(MobileTokenDenied):
                validate_candidate_access(access)
        self._connections_drained()

    def test_revocation_racing_new_issuance_never_resurrects(self):
        old_access, _ = issue_verified_candidate_session(
            user_id=self.user.pk, verified_mfa=False, mfa_epoch=None,
            expected_generation=0,
        )
        start = Barrier(3)

        def contender_issue():
            connections.close_all()
            try:
                start.wait(timeout=12)
                try:
                    return issue_verified_candidate_session(
                        user_id=self.user.pk, verified_mfa=False,
                        mfa_epoch=None, expected_generation=0,
                    )
                except MobileTokenDenied:
                    return None
            finally:
                connections.close_all()

        def contender_revoke():
            connections.close_all()
            try:
                start.wait(timeout=12)
                return revoke_all_candidate_devices(user_id=self.user.pk)
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            issued_job = pool.submit(contender_issue)
            revoked_job = pool.submit(contender_revoke)
            start.wait(timeout=12)
            issued = issued_job.result(timeout=35)
            revoked_job.result(timeout=35)

        self.assertEqual(
            MobileAccountFence.objects.get(user_id=self.user.pk).generation, 1,
        )
        self.assertFalse(MobileDeviceSession.objects.filter(
            user_id=self.user.pk, revoked_at__isnull=True,
        ).exists())
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(old_access)
        if issued is not None:
            with self.assertRaises(MobileTokenDenied):
                validate_candidate_access(issued[0])
        self._connections_drained()

    def _connections_drained(self):
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM pg_stat_activity "
                "WHERE datname = current_database() "
                "AND pid <> pg_backend_pid() "
                "AND backend_type = 'client backend'"
            )
            self.assertEqual(cursor.fetchone()[0], 0)
