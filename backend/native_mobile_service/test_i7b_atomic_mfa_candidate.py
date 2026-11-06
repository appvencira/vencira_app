"""I7-B: disposable PostgreSQL 17 transactional MFA/issuance proof.

No production endpoint or external caller authority is tested or granted.
"""
import uuid
from datetime import timedelta

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState

from .g14_e2_atomic_mfa_candidate import candidate_mfa_atomic_flow
from .g5_audit import MobileAuditDenied
from .models import MobileAuthAuditEvent, MobileAuthAttemptBucket, MobileDeviceSession
from .session_store import (
    MobileTokenDenied, rotate_candidate_refresh, validate_candidate_access,
)


@override_settings(
    VENCIRA_G5_ABUSE_KEY="i7b-disposable-abuse-key-only-for-ci-postgres17",
    VENCIRA_G5_AUDIT_KEY="i7b-disposable-audit-key-only-for-ci-postgres17",
)
class I7BAtomicMfaCandidatePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("I7-B runs on disposable PostgreSQL17 only")
        self.user = get_user_model().objects.create_user(
            username="i7b-synthetic-mfa", password="i7b-synthetic-password",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.timestamp = 300000
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=7,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def attempt(self, *, event_id=None, password="i7b-synthetic-password",
                code=None, username="i7b-synthetic-mfa", keys=None):
        return candidate_mfa_atomic_flow(
            username=username, password=password,
            code=code if code is not None else totp_at(self.secret, self.timestamp),
            keys=self.keys if keys is None else keys,
            timestamp=self.timestamp,
            request_meta={"REMOTE_ADDR": "198.51.100.16"},
            event_id=event_id or uuid.uuid4(),
        )

    def test_correct_password_and_consumed_totp_issue_audited_session(self):
        pair = self.attempt()
        self.assertIsNotNone(pair)
        self.assertEqual(len(pair), 2)
        self.assertEqual(validate_candidate_access(pair[0]).pk, self.user.pk)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)
        session = MobileDeviceSession.objects.get()
        self.assertTrue(session.verified_mfa)
        self.assertEqual(session.mfa_epoch, 7)
        self.assertEqual(
            list(MobileAuthAuditEvent.objects.values_list("event_type", flat=True)),
            ["auth_verified"],
        )
        # Never persist bearer plaintext in user or session fields.
        self.assertNotEqual(session.refresh_digest, pair[1])
        self.assertNotEqual(session.access_digest, pair[0])

    def test_wrong_password_never_consumes_factor_or_creates_session(self):
        self.assertIsNone(self.attempt(password="incorrect"))
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.get().event_type, "auth_denied")
        self.assertEqual(MobileAuthAttemptBucket.objects.count(), 2)

    def test_wrong_totp_persists_account_lockout_writer_and_denial(self):
        correct = totp_at(self.secret, self.timestamp)
        invalid = "000000" if correct != "000000" else "111111"
        self.assertIsNone(self.attempt(code=invalid))
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertEqual(self.state.failed_attempts, 1)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.get().event_type, "auth_denied")

    def test_same_totp_counter_cannot_issue_a_second_device(self):
        first = self.attempt()
        self.assertIsNotNone(first)
        self.assertIsNone(self.attempt())
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 2)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, 10000)

    def test_preexisting_audit_id_rolls_back_totp_consumption_and_issuance(self):
        event_id = uuid.uuid4()
        self.assertIsNone(self.attempt(event_id=event_id, password="wrong"))
        with self.assertRaises(MobileAuditDenied):
            self.attempt(event_id=event_id)
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)

    def test_pending_recovery_denies_without_factor_consumption(self):
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        self.assertIsNone(self.attempt())
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_missing_or_incorrect_key_cannot_create_session(self):
        with self.assertRaises(Exception):
            self.attempt(keys=[Fernet.generate_key().decode("ascii")])
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.state.refresh_from_db()
        self.assertEqual(self.state.last_accepted_counter, -1)

    def test_successful_refresh_rotation_and_replay_revokes_candidate(self):
        access, refresh = self.attempt()
        next_access, next_refresh = rotate_candidate_refresh(refresh)
        self.assertNotEqual(next_access, access)
        self.assertNotEqual(next_refresh, refresh)
        self.assertEqual(validate_candidate_access(next_access).pk, self.user.pk)
        with self.assertRaises(MobileTokenDenied):
            rotate_candidate_refresh(refresh)
        with self.assertRaises(MobileTokenDenied):
            validate_candidate_access(next_access)
        self.assertIsNotNone(MobileDeviceSession.objects.get().revoked_at)
