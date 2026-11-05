"""G14-D3 PostgreSQL-only races: no operational login or live database."""
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Event
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.db import connection, connections, transaction
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_enrollment import finalize_mfa
from reminders.models import UserMfaState, UserMfaRecoveryCode

from . import g14_d3_candidate_boundary as boundary
from .models import MobileDeviceSession
from .session_store import (
    MobileTokenDenied, revoke_all_candidate_devices, validate_candidate_access,
)


@override_settings(
    VENCIRA_G5_ABUSE_KEY="g14d3-pg17-race-synthetic-abuse-key-only",
    VENCIRA_G5_AUDIT_KEY="g14d3-pg17-race-synthetic-audit-key-only",
)
class G14D3CandidatePG17RaceTests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("Real PostgreSQL row locks required")
        self.user = get_user_model().objects.create_user(
            username="g14d3-race", password="synthetic-g14d3-race",
        )

    def _issue_held_until(self, verified, release):
        original = boundary.verify_candidate_password_only

        def hold_verification(*, username, password):
            result = original(username=username, password=password)
            verified.set()
            if not release.wait(timeout=15):
                raise RuntimeError("Timed out waiting for test barrier")
            return result

        connections.close_all()
        try:
            with patch.object(boundary, "verify_candidate_password_only",
                              side_effect=hold_verification):
                return boundary.candidate_non_mfa_flow(
                    username="g14d3-race",
                    password="synthetic-g14d3-race",
                    request_meta={"REMOTE_ADDR": "198.51.100.10"},
                    event_id=uuid.uuid4(),
                )
        finally:
            connections.close_all()

    def test_revoke_waits_for_locked_issuance_and_no_session_survives(self):
        verified, release = Event(), Event()

        def revoke():
            connections.close_all()
            try:
                revoke_all_candidate_devices(user_id=self.user.pk)
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            issuance = pool.submit(self._issue_held_until, verified, release)
            self.assertTrue(verified.wait(timeout=15))
            revocation = pool.submit(revoke)
            release.set()
            pair = issuance.result(timeout=40)
            revocation.result(timeout=40)

        self.assertIsNotNone(pair)
        self.assertFalse(MobileDeviceSession.objects.filter(
            user_id=self.user.pk, revoked_at__isnull=True,
        ).exists())
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(pair[0])

    def test_password_rotation_after_issuance_invalidates_access(self):
        verified, release = Event(), Event()

        def rotate_password():
            connections.close_all()
            try:
                with transaction.atomic():
                    user = get_user_model().objects.select_for_update().get(
                        pk=self.user.pk,
                    )
                    user.set_password("g14d3-rotated-synthetic")
                    user.save(update_fields=["password"])
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            issuance = pool.submit(self._issue_held_until, verified, release)
            self.assertTrue(verified.wait(timeout=15))
            rotation = pool.submit(rotate_password)
            release.set()
            pair = issuance.result(timeout=40)
            rotation.result(timeout=40)

        self.assertIsNotNone(pair)
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(pair[0])

    def test_mfa_finalization_after_locked_issuance_invalidates_access(self):
        # Synthetic recovery hashes and mocked verifier: no live MFA keys.
        state = UserMfaState.objects.create(
            user=self.user, enabled=False,
            encrypted_totp_secret="synthetic-not-used",
            prepared_at=timezone.now(),
        )
        UserMfaRecoveryCode.objects.bulk_create([
            UserMfaRecoveryCode(state=state, code_hash=f"synthetic-{i}")
            for i in range(10)
        ])
        verified, release = Event(), Event()

        def activate_mfa():
            connections.close_all()
            try:
                with patch(
                    "reminders.mfa_secrets.verify_recovery_code",
                    return_value=True,
                ):
                    return finalize_mfa(
                        self.user.pk, "s" * 32,
                        issued_at=int(timezone.now().timestamp()),
                    )
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=2) as pool:
            issuance = pool.submit(self._issue_held_until, verified, release)
            self.assertTrue(verified.wait(timeout=15))
            activation = pool.submit(activate_mfa)
            release.set()
            pair = issuance.result(timeout=40)
            self.assertTrue(activation.result(timeout=40))

        self.assertTrue(UserMfaState.objects.get(user=self.user).enabled)
        self.assertIsNotNone(pair)
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(pair[0])
