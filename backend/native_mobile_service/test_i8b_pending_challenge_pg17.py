"""I8-B isolated PG17 one-time challenge lifecycle, no HTTP/issuance."""
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import connection, close_old_connections
from django.test import TransactionTestCase
from django.utils import timezone

from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from .candidate_challenge_store import (
    CandidateChallengeDenied, create_pending_candidate_challenge,
    retire_pending_candidate_challenge,
)
from .models import MobileAccountFence, MobileDeviceSession, MobilePendingChallenge


class I8BPendingChallengePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("PostgreSQL17 isolated lab required")
        self.user = get_user_model().objects.create_user(
            username="i8b-synthetic", password="synthetic-password-not-used",
        )
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=7,
            encrypted_totp_secret="unusable-test-secret",
        )

    def wire(self):
        return create_pending_candidate_challenge(user_id=self.user.pk)

    def test_one_time_retirement_no_session(self):
        wire = self.wire()
        self.assertEqual(MobilePendingChallenge.objects.count(), 1)
        self.assertIsNone(retire_pending_candidate_challenge(wire=wire))
        self.assertIsNotNone(MobilePendingChallenge.objects.get().consumed_at)
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)
        self.assertFalse(MobileDeviceSession.objects.exists())


    def test_concurrent_retirement_only_one_winner(self):
        wire = self.wire()
        start = Barrier(2)

        def attempt():
            close_old_connections()
            try:
                start.wait(timeout=10)
                try:
                    retire_pending_candidate_challenge(wire=wire)
                    return "retired"
                except CandidateChallengeDenied:
                    return "denied"
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(attempt)
            second = pool.submit(attempt)
            outcomes = sorted((first.result(timeout=20), second.result(timeout=20)))
        self.assertEqual(outcomes, ["denied", "retired"])
        self.assertEqual(MobilePendingChallenge.objects.count(), 1)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_expiry_denies_without_consuming(self):
        wire = self.wire()
        MobilePendingChallenge.objects.update(
            expires_at=timezone.now() - timedelta(seconds=1),
        )
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)

    def test_tampered_secret_and_unknown_id(self):
        wire = self.wire()
        other = self.wire()
        broken = wire[:37] + other[37:]
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=broken)
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=f"lc1.{uuid.uuid4().hex}." + wire.split(".")[2])
        self.assertIsNone(MobilePendingChallenge.objects.first().consumed_at)

    def test_password_change_invalidates_unconsumed(self):
        wire = self.wire()
        self.user.set_password("new-secret-value")
        self.user.save(update_fields=["password"])
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)

    def test_mfa_epoch_rotation_invalidates_unconsumed(self):
        wire = self.wire()
        self.state.session_epoch += 1
        self.state.save(update_fields=["session_epoch"])
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)

    def test_account_generation_change_invalidates(self):
        wire = self.wire()
        MobileAccountFence.objects.create(user=self.user, generation=1)
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)

    def test_recovery_pending_invalidates(self):
        wire = self.wire()
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)

    def test_disabled_account_or_mfa_denies(self):
        wire = self.wire()
        self.state.enabled = False
        self.state.save(update_fields=["enabled"])
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)
        self.state.enabled = True
        self.state.save(update_fields=["enabled"])
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(CandidateChallengeDenied):
            retire_pending_candidate_challenge(wire=wire)

    def test_non_mfa_account_cannot_create(self):
        self.state.delete()
        with self.assertRaises(CandidateChallengeDenied):
            self.wire()

    def test_ttl_limits(self):
        for ttl in (0, 301, True, "300"):
            with self.subTest(ttl=ttl), self.assertRaises(CandidateChallengeDenied):
                create_pending_candidate_challenge(
                    user_id=self.user.pk, ttl_seconds=ttl,
                )
        self.assertFalse(MobilePendingChallenge.objects.exists())

    def test_retirement_does_not_verify_factor_or_issue_token(self):
        wire = self.wire()
        self.assertIsNone(retire_pending_candidate_challenge(wire=wire))
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertFalse(hasattr(MobilePendingChallenge.objects.get(), "totp_verified"))
