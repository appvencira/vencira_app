"""D27 PG17 isolated independent issuer core: real Django password/TOTP."""
import os
import time
import uuid
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from reminders.native_mobile_token_primitives import (
    matches_native_token, parse_native_token,
)
from .models import (
    MobileAuthAttemptBucket, MobileAuthAuditEvent,
    MobileDeviceSession, MobilePendingChallenge,
)
from .native_operational_issuer_core import (
    OperationalCoreDenied, begin_verified_password, complete_verified_mfa,
    validate_verified_access, rotate_verified_refresh, revoke_verified_device,
    begin_recovery_password, complete_recovery_mfa,
)


@override_settings(
    VENCIRA_D27_CORE_AUDIT_KEY="d27-independent-audit-secret-2026-verified",
    VENCIRA_D27_CORE_ABUSE_KEY="d27-independent-abuse-secret-2026-verified",
)
class D27IndependentIssuerCorePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D27 security race gates require isolated PG17")
        key = Fernet.generate_key().decode("ascii")
        env = patch.dict(os.environ, {
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        })
        env.start()
        self.addCleanup(env.stop)
        self.user = get_user_model().objects.create_user(
            username="d27-reader", password="d27-synthetic-password",
        )
        self.secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[key],
            ),
        )

    def begin(self, *, password="d27-synthetic-password", username="d27-reader"):
        return begin_verified_password(
            username=username, password=password,
            remote_addr="198.51.100.77",
        )

    def test_password_mfa_issue_digested_tokens_and_deny_replay(self):
        wire = self.begin()
        self.assertRegex(wire, r"^oc1\.[0-9a-f]{32}\.[A-Za-z0-9_-]{43}$")
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        issued = complete_verified_mfa(
            challenge=wire, code=totp_at(self.secret, int(time.time())),
        )
        self.assertEqual(len(issued), 2)
        access, refresh = issued
        row = MobileDeviceSession.objects.get()
        self.assertEqual(parse_native_token(access, kind="a"), row.id)
        self.assertTrue(matches_native_token(
            access, kind="a", stored_digest=row.access_digest,
        ))
        self.assertTrue(matches_native_token(
            refresh, kind="r", stored_digest=row.refresh_digest,
        ))
        self.assertNotIn(access, str(row.__dict__))
        self.assertNotIn(refresh, str(row.__dict__))
        self.assertIsNotNone(MobilePendingChallenge.objects.get().consumed_at)
        self.assertEqual(
            MobileAuthAuditEvent.objects.filter(event_type="auth_verified").count(),
            1,
        )
        with self.assertRaises(OperationalCoreDenied):
            complete_verified_mfa(challenge=wire, code="111111")
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        print("D27_INDEPENDENT_PASSWORD_MFA_SESSION_PG17=PASS")

    def test_wrong_password_and_invalid_factor_do_not_issue(self):
        self.assertIsNone(self.begin(password="wrong-password"))
        self.assertEqual(MobilePendingChallenge.objects.count(), 0)
        wire = self.begin()
        # Invalid format is uniformly denied, never creates bearer material.
        with self.assertRaises(OperationalCoreDenied):
            complete_verified_mfa(challenge=wire, code="not-a-code")
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertEqual(
            MobileAuthAuditEvent.objects.filter(event_type="auth_denied").count(),
            1,
        )
        print("D27_BAD_PASSWORD_AND_MFA_DENIED_PG17=PASS")

    def test_missing_key_and_disabled_environment_fail_closed(self):
        with override_settings(VENCIRA_D27_CORE_AUDIT_KEY="short"):
            with self.assertRaises(OperationalCoreDenied):
                self.begin()
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(OperationalCoreDenied):
                self.begin()
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            with self.assertRaises(OperationalCoreDenied):
                self.begin()
        self.assertEqual(MobilePendingChallenge.objects.count(), 0)
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        print("D27_PRODUCTION_AND_KEY_GUARDS=PASS")

    def test_refresh_rotation_replay_revokes_device_and_stale_access(self):
        wire = self.begin()
        access, refresh = complete_verified_mfa(
            challenge=wire, code=totp_at(self.secret, int(time.time())),
        )
        self.assertEqual(validate_verified_access(access).pk, self.user.pk)
        next_access, next_refresh = rotate_verified_refresh(refresh)
        with self.assertRaises(OperationalCoreDenied):
            validate_verified_access(access)
        self.assertEqual(validate_verified_access(next_access).pk, self.user.pk)
        with self.assertRaises(OperationalCoreDenied):
            rotate_verified_refresh(refresh)
        with self.assertRaises(OperationalCoreDenied):
            validate_verified_access(next_access)
        with self.assertRaises(OperationalCoreDenied):
            rotate_verified_refresh(next_refresh)
        self.assertIsNotNone(MobileDeviceSession.objects.get().revoked_at)
        print("D27_REFRESH_ROTATION_REPLAY_REVOKES_PG17=PASS")

    def test_verified_logout_revokes_access_and_refresh(self):
        wire = self.begin()
        access, refresh = complete_verified_mfa(
            challenge=wire, code=totp_at(self.secret, int(time.time())),
        )
        revoke_verified_device(refresh)
        with self.assertRaises(OperationalCoreDenied):
            validate_verified_access(access)
        with self.assertRaises(OperationalCoreDenied):
            rotate_verified_refresh(refresh)
        with self.assertRaises(OperationalCoreDenied):
            revoke_verified_device(refresh)
        print("D27_DEVICE_LOGOUT_SERVER_REVOKED_PG17=PASS")

    def test_account_wide_recovery_revokes_old_device_and_rejects_replay(self):
        normal = self.begin()
        old_access, old_refresh = complete_verified_mfa(
            challenge=normal, code=totp_at(self.secret, int(time.time()) - 30),
        )
        self.assertEqual(validate_verified_access(old_access).pk, self.user.pk)
        challenge = begin_recovery_password(
            username="d27-reader", password="d27-synthetic-password",
            remote_addr="198.51.100.77",
        )
        self.assertTrue(challenge.startswith("or1."))
        self.assertIsNone(
            MobileDeviceSession.objects.filter(revoked_at__isnull=False).first(),
        )
        with self.assertRaises(OperationalCoreDenied):
            complete_verified_mfa(challenge=challenge, code="000000")
        with self.assertRaises(OperationalCoreDenied):
            complete_recovery_mfa(challenge=normal, code="000000")
        fresh_access, fresh_refresh = complete_recovery_mfa(
            challenge=challenge, code=totp_at(self.secret, int(time.time())),
        )
        with self.assertRaises(OperationalCoreDenied):
            validate_verified_access(old_access)
        with self.assertRaises(OperationalCoreDenied):
            rotate_verified_refresh(old_refresh)
        self.assertEqual(validate_verified_access(fresh_access).pk, self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.count(), 2)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=False,
        ).count(), 1)
        self.assertEqual(MobileAuthAuditEvent.objects.filter(
            event_type="account_revoke",
        ).count(), 1)
        with self.assertRaises(OperationalCoreDenied):
            complete_recovery_mfa(challenge=challenge, code="000000")
        revoke_verified_device(fresh_refresh)
        print("D27_ACCOUNT_RECOVERY_REVOKES_OLD_PG17=PASS")

    def test_account_recovery_audit_failure_rolls_back_revocation(self):
        normal = self.begin()
        old_access, _ = complete_verified_mfa(
            challenge=normal, code=totp_at(self.secret, int(time.time()) - 30),
        )
        challenge = begin_recovery_password(
            username="d27-reader", password="d27-synthetic-password",
            remote_addr="198.51.100.77",
        )
        from . import native_operational_issuer_core as core
        original = core._event

        def failed_recovery_audit(key, event_type, actor):
            if event_type == "account_revoke":
                raise RuntimeError("synthetic audit store failure")
            return original(key, event_type, actor)

        with patch.object(core, "_event", side_effect=failed_recovery_audit):
            with self.assertRaises(RuntimeError):
                complete_recovery_mfa(
                    challenge=challenge,
                    code=totp_at(self.secret, int(time.time())),
                )
        self.assertEqual(validate_verified_access(old_access).pk, self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertIsNone(MobilePendingChallenge.objects.get(
            pk=uuid.UUID(hex=challenge.split(".")[1]),
        ).consumed_at)
        print("D27_RECOVERY_AUDIT_FAILURE_ROLLBACK_PG17=PASS")

    def test_wrong_password_never_revokes_existing_sessions(self):
        normal = self.begin()
        old_access, _ = complete_verified_mfa(
            challenge=normal, code=totp_at(self.secret, int(time.time()) - 30),
        )
        denied = begin_recovery_password(
            username="d27-reader", password="wrong-password",
            remote_addr="198.51.100.77",
        )
        self.assertIsNone(denied)
        self.assertEqual(validate_verified_access(old_access).pk, self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True,
        ).count(), 1)
        print("D27_RECOVERY_PASSWORD_ONLY_NO_REVOKE_PG17=PASS")

    def test_rate_limit_consumed_before_password_and_ip_bound(self):
        for _ in range(4):
            self.assertIsNone(self.begin(username="unknown", password="wrong"))
        self.assertIsNone(self.begin(username="unknown", password="wrong"))
        self.assertFalse(self.begin(username="unknown", password="wrong"))
        self.assertEqual(MobileDeviceSession.objects.count(), 0)
        self.assertEqual(
            MobileAuthAttemptBucket.objects.filter(scope="account").count(),
            1,
        )
        self.assertEqual(
            MobileAuthAttemptBucket.objects.filter(scope="ip").count(), 1,
        )
        with self.assertRaises(OperationalCoreDenied):
            begin_verified_password(
                username="d27-reader", password="d27-synthetic-password",
                remote_addr="not-an-ip",
            )
        print("D27_INDEPENDENT_ANTIBRUTEFORCE_AND_IP=PASS")
