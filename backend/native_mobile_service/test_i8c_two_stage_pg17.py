"""I8-C PostgreSQL 17 test-only two-step protocol: never an HTTP issuer."""
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from datetime import timedelta

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, close_old_connections
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState

from .candidate_challenge_store import CandidateChallengeDenied
from .candidate_two_step_issuer import (
    candidate_mfa_challenge_to_session, candidate_password_to_challenge,
)
from .g5_audit import MobileAuditDenied
from .models import MobileAuthAuditEvent, MobileDeviceSession, MobilePendingChallenge
from .session_store import MobileTokenDenied, validate_candidate_access


@override_settings(
    VENCIRA_G5_ABUSE_KEY="i8c-disposable-abuse-key-only-for-ci-postgres17",
    VENCIRA_G5_AUDIT_KEY="i8c-disposable-audit-key-only-for-ci-postgres17",
)
class I8CTwoStagePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("Disposable PostgreSQL17 required")
        self.user = get_user_model().objects.create_user(
            username="i8c-synthetic", password="synthetic-i8c-password",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.timestamp = 300000
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=8,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def password(self, *, password="synthetic-i8c-password", event_id=None):
        return candidate_password_to_challenge(
            username=self.user.username, password=password,
            event_id=event_id or uuid.uuid4(),
            request_meta={"REMOTE_ADDR": "198.51.100.17"},
        )

    def finish(self, wire, *, code=None, keys=None, event_id=None):
        return candidate_mfa_challenge_to_session(
            wire=wire,
            code=code if code is not None else totp_at(self.secret, self.timestamp),
            keys=self.keys if keys is None else keys,
            event_id=event_id or uuid.uuid4(),
            timestamp=self.timestamp,
        )

    def test_real_password_then_totp_issues_only_after_consumption(self):
        wire = self.password()
        self.assertIsInstance(wire, str)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        access, refresh = self.finish(wire)
        self.assertEqual(validate_candidate_access(access).pk, self.user.pk)
        self.assertIsNotNone(refresh)
        self.assertIsNotNone(MobilePendingChallenge.objects.get().consumed_at)
        self.assertEqual(
            list(MobileAuthAuditEvent.objects.values_list("event_type", flat=True)),
            ["auth_verified"],
        )

    def test_wrong_password_does_not_create_challenge(self):
        self.assertIsNone(self.password(password="wrong"))
        self.assertEqual(MobilePendingChallenge.objects.count(), 0)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertEqual(MobileAuthAuditEvent.objects.get().event_type, "auth_denied")

    def test_wrong_factor_persists_failure_without_issuing(self):
        wire = self.password()
        correct = totp_at(self.secret, self.timestamp)
        wrong = "000000" if correct != "000000" else "111111"
        self.assertIsNone(self.finish(wire, code=wrong))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 1)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)
        self.assertEqual(self.finish(wire)[0].startswith("v1.a."), True)

    def test_replay_does_not_issue_twice(self):
        wire = self.password()
        self.finish(wire)
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    def test_same_totp_against_second_challenge_fails(self):
        first = self.password()
        second = self.password()
        self.finish(first)
        self.assertIsNone(self.finish(second))
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    def test_expiration_prevents_issuance(self):
        wire = self.password()
        MobilePendingChallenge.objects.update(
            expires_at=timezone.now() - timedelta(seconds=1),
        )
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_changed_credential_and_epoch_prevents_issuance(self):
        wire = self.password()
        self.user.set_password("different-password-value")
        self.user.save(update_fields=["password"])
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_pending_recovery_prevents_issuance(self):
        wire = self.password()
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        with self.assertRaises(CandidateChallengeDenied):
            self.finish(wire)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_audit_failure_rolls_back_all_writes(self):
        wire = self.password()
        event_id = uuid.uuid4()
        self.finish(wire, code="000000" if totp_at(self.secret, self.timestamp) != "000000" else "111111", event_id=event_id)
        with self.assertRaises(MobileAuditDenied):
            self.finish(wire, event_id=event_id)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)

    def test_bad_encryption_key_cannot_issue(self):
        wire = self.password()
        with self.assertRaises(Exception):
            self.finish(wire, keys=[Fernet.generate_key().decode("ascii")])
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertIsNone(MobilePendingChallenge.objects.get().consumed_at)

    def test_concurrent_completion_one_issuance(self):
        wire = self.password()
        start = Barrier(2)

        def finish():
            close_old_connections()
            try:
                start.wait(timeout=15)
                try:
                    return "issued" if self.finish(wire) else "denied"
                except CandidateChallengeDenied:
                    return "denied"
            finally:
                close_old_connections()
        with ThreadPoolExecutor(max_workers=2) as pool:
            a = pool.submit(finish)
            b = pool.submit(finish)
            self.assertEqual(sorted((a.result(timeout=30), b.result(timeout=30))),
                             ["denied", "issued"])
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
