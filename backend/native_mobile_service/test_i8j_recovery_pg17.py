"""I8-J: atomic recovery only in disposable PostgreSQL17 with no routes."""
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import close_old_connections, connection
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState

from .candidate_challenge_store import CandidateChallengeDenied
from .candidate_recovery_issuer import (
    recovery_mfa_to_atomic_session, recovery_password_to_challenge,
)
from .candidate_two_step_issuer import (
    candidate_password_to_challenge, candidate_mfa_challenge_to_session,
)
from .g5_audit import MobileAuditDenied
from .models import (
    MobileAccountFence, MobileAuthAuditEvent,
    MobileDeviceSession, MobilePendingChallenge,
)
from .session_store import (
    MobileTokenDenied, validate_candidate_access, rotate_candidate_refresh,
)


@override_settings(
    VENCIRA_G5_ABUSE_KEY="i8j-disposable-abuse-only-postgres17",
    VENCIRA_G5_AUDIT_KEY="i8j-disposable-audit-only-postgres17",
)
class I8JAtomicRecoveryPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("I8-J disposable PostgreSQL17 required")
        self.user = get_user_model().objects.create_user(
            username="i8j-synthetic", password="synthetic-i8j-password",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.timestamp = 300000
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=4,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def password(self, *, recovery=True, password="synthetic-i8j-password"):
        caller = (recovery_password_to_challenge if recovery
                  else candidate_password_to_challenge)
        return caller(
            username=self.user.username, password=password,
            request_meta={"REMOTE_ADDR": "198.51.100.49"},
            event_id=uuid.uuid4(),
        )

    def finish(self, wire, *, recovery=True, event_id=None, code=None,
               timestamp=None):
        caller = (recovery_mfa_to_atomic_session if recovery
                  else candidate_mfa_challenge_to_session)
        return caller(
            wire=wire, code=code or totp_at(self.secret, self.timestamp),
            keys=self.keys, event_id=event_id or uuid.uuid4(),
            timestamp=self.timestamp if timestamp is None else timestamp,
        )

    def test_new_password_mfa_recovery_revokes_all_old_devices(self):
        # Old sessions can be issued after fresh TOTP with independent counters.
        old1 = self.finish(self.password(recovery=False), recovery=False)
        old2 = self.finish(
            self.password(recovery=False), recovery=False,
            timestamp=self.timestamp + 30,
            code=totp_at(self.secret, self.timestamp + 30),
        )
        wire = self.password()
        self.assertEqual(MobileDeviceSession.objects.count(), 2)
        pair = self.finish(
            wire, timestamp=self.timestamp + 60,
            code=totp_at(self.secret, self.timestamp + 60),
        )
        self.assertEqual(validate_candidate_access(pair[0]).pk, self.user.pk)
        for old in (old1, old2):
            with self.assertRaises(MobileTokenDenied):
                validate_candidate_access(old[0])
            with self.assertRaises(MobileTokenDenied):
                rotate_candidate_refresh(old[1])
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        self.assertEqual(MobileAccountFence.objects.get(user=self.user).generation, 1)
        self.assertEqual(MobileAuthAuditEvent.objects.filter(
            event_type="account_revoke").count(), 1)

    def test_regular_login_challenge_cannot_be_promoted_to_recovery(self):
        wire = self.password(recovery=False)
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)

    def test_recovery_challenge_cannot_be_used_for_normal_login(self):
        wire = self.password()
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire, recovery=False)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)

    def test_wrong_password_no_recovery_challenge(self):
        self.assertIsNone(self.password(password="invalid"))
        self.assertFalse(MobilePendingChallenge.objects.exists())
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_factor_leaves_old_session_and_recovery_pending(self):
        wire = self.password()
        correct = totp_at(self.secret, self.timestamp)
        wrong = "000000" if correct != "000000" else "111111"
        self.assertIsNone(self.finish(wire, code=wrong))
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)
        self.assertEqual(self.finish(wire)[0].startswith("v1.a."), True)

    def test_replayed_challenge_cannot_revoke_new_session(self):
        wire = self.password()
        pair = self.finish(wire)
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertEqual(validate_candidate_access(pair[0]).pk, self.user.pk)
        self.assertEqual(MobileAccountFence.objects.get(user=self.user).generation, 1)

    def test_expired_challenge_cannot_revoke(self):
        wire = self.password()
        MobilePendingChallenge.objects.update(
            expires_at=timezone.now() - timedelta(seconds=1),
        )
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertFalse(MobileAccountFence.objects.exists())
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_audit_failure_rolls_back_generation_revoke_and_issuance(self):
        old = self.finish(self.password(recovery=False), recovery=False)
        wire = self.password()
        event_id = uuid.uuid4()
        # Make the auth_verified audit's event-id already occupied by denial.
        from .g5_audit import record_candidate_auth_event
        record_candidate_auth_event(
            event_id=event_id, event_type="auth_denied", actor=self.user.username,
        )
        with self.assertRaises(MobileAuditDenied):
            self.finish(
                wire, event_id=event_id,
                timestamp=self.timestamp + 30,
                code=totp_at(self.secret, self.timestamp + 30),
            )
        self.assertEqual(validate_candidate_access(old[0]).pk, self.user.pk)
        self.assertFalse(MobileAccountFence.objects.exists())
        self.assertIsNone(MobilePendingChallenge.objects.get(pk__isnull=False,
            secret_digest__isnull=False,
            consumed_at__isnull=True).consumed_at)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)

    def test_concurrent_recovery_only_one_wins_and_preserves_session(self):
        wire = self.password()
        barrier = Barrier(2)

        def finish():
            close_old_connections()
            try:
                barrier.wait(timeout=20)
                try:
                    return self.finish(wire)
                except CandidateChallengeDenied:
                    return None
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(finish)
            b = pool.submit(finish)
            result = [a.result(timeout=45), b.result(timeout=45)]
        self.assertEqual(sum(x is not None for x in result), 1)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(MobileAccountFence.objects.get(user=self.user).generation, 1)
