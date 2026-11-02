"""Password and MFA gates against REAL ephemeral Django database tables.

The lab is test-only; no URLs, DRF auth, production migration or live tokens.
"""
from datetime import timedelta
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import (
    LoginAttemptBucket, MfaAdministrativeRecoveryCase, UserMfaState,
)

from .login_rules import (
    NativeLoginLabDenied, begin_native_login_lab, finish_native_mfa_lab,
)
from .models import MobileDeviceSessionLab, MobileLoginChallengeLab
from .session_rules import validate_access, revoke_all_devices_for_user_lab

PASSWORD = "SyntheticLabPassword-2026!"


class NativeLoginFlowLabTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="n1-lab-login", password=PASSWORD,
        )

    def setUp(self):
        self.key = Fernet.generate_key().decode("ascii")
        self.secret = generate_secret()

    def enable_mfa(self):
        return UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=4,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[self.key],
            ),
        )

    def challenge(self):
        mode, raw = begin_native_login_lab(self.user.username, PASSWORD)
        self.assertEqual(mode, "mfa")
        return raw

    def valid_mfa(self, challenge):
        code = totp_at(self.secret, int(timezone.now().timestamp()))
        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": self.key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            return finish_native_mfa_lab(challenge, code)

    def test_correct_password_without_mfa_creates_device_session(self):
        mode, tokens = begin_native_login_lab(self.user.username, PASSWORD)
        self.assertEqual(mode, "ready")
        self.assertEqual(validate_access(tokens[0]).pk, self.user.pk)
        self.assertEqual(MobileDeviceSessionLab.objects.count(), 1)

    def test_wrong_password_never_creates_device_session(self):
        with self.assertRaises(NativeLoginLabDenied):
            begin_native_login_lab(self.user.username, "wrong")
        self.assertFalse(MobileDeviceSessionLab.objects.exists())
        self.assertFalse(MobileLoginChallengeLab.objects.exists())
        self.assertEqual(LoginAttemptBucket.objects.count(), 1)

    def test_password_failures_block_even_correct_password(self):
        for _ in range(5):
            with self.assertRaises(NativeLoginLabDenied):
                begin_native_login_lab(self.user.username, "bad")
        with self.assertRaises(NativeLoginLabDenied):
            begin_native_login_lab(self.user.username, PASSWORD)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_mfa_password_step_issues_only_challenge(self):
        self.enable_mfa()
        raw = self.challenge()
        record = MobileLoginChallengeLab.objects.get()
        self.assertNotIn(raw, (record.secret_digest, record.credential_version))
        self.assertEqual(record.mfa_epoch, 4)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_mfa_success_issues_only_once(self):
        self.enable_mfa()
        raw = self.challenge()
        access, refresh = self.valid_mfa(raw)
        self.assertEqual(validate_access(access).pk, self.user.pk)
        self.assertTrue(refresh.startswith("v1.r."))
        self.assertIsNotNone(MobileLoginChallengeLab.objects.get().consumed_at)
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)
        self.assertEqual(MobileDeviceSessionLab.objects.count(), 1)

    def test_invalid_totp_persists_failed_attempt_counter(self):
        self.enable_mfa()
        raw = self.challenge()
        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": self.key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            with self.assertRaises(NativeLoginLabDenied):
                finish_native_mfa_lab(raw, "badotp")
        state = UserMfaState.objects.get(user=self.user)
        self.assertEqual(state.failed_attempts, 1)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())
        self.assertIsNone(MobileLoginChallengeLab.objects.get().consumed_at)

    def test_missing_mfa_keyring_does_not_issue(self):
        self.enable_mfa()
        raw = self.challenge()
        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": "",
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            with self.assertRaises(NativeLoginLabDenied):
                finish_native_mfa_lab(raw, "123456")
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_expired_challenge_denied(self):
        self.enable_mfa()
        raw = self.challenge()
        MobileLoginChallengeLab.objects.update(
            expires_at=timezone.now() - timedelta(seconds=1))
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_password_rotation_invalidates_pending_challenge(self):
        self.enable_mfa()
        raw = self.challenge()
        self.user.set_password("ChangedSyntheticLabPassword-2026!")
        self.user.save(update_fields=["password"])
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)

    def test_factor_epoch_change_invalidates_pending_challenge(self):
        state = self.enable_mfa()
        raw = self.challenge()
        state.session_epoch = 5
        state.save(update_fields=["session_epoch"])
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)

    def test_administrative_recovery_blocks_pending_challenge(self):
        self.enable_mfa()
        raw = self.challenge()
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            status=MfaAdministrativeRecoveryCase.Status.PENDING,
            quarantine_until=now + timedelta(days=1),
            expires_at=now + timedelta(days=2),
        )
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)

    def test_global_revocation_invalidates_preexisting_mfa_challenge(self):
        self.enable_mfa()
        raw = self.challenge()
        self.assertEqual(
            revoke_all_devices_for_user_lab(user_id=self.user.pk), 0)
        record = MobileLoginChallengeLab.objects.get()
        self.assertIsNotNone(record.consumed_at)
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(raw)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_fresh_password_and_mfa_can_login_after_revocation(self):
        self.enable_mfa()
        old = self.challenge()
        revoke_all_devices_for_user_lab(user_id=self.user.pk)
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(old)
        new = self.challenge()
        fresh = MobileLoginChallengeLab.objects.get(secret_digest__isnull=False,
                                                   consumed_at__isnull=True)
        self.assertEqual(fresh.auth_generation, 1)
        access, refresh = self.valid_mfa(new)
        self.assertEqual(validate_access(access).pk, self.user.pk)
        self.assertTrue(refresh.startswith("v1.r."))

    def test_revoke_with_no_mfa_blocks_old_session_and_accepts_fresh_login(self):
        old_mode, old_tokens = begin_native_login_lab(self.user.username, PASSWORD)
        self.assertEqual(old_mode, "ready")
        self.assertEqual(revoke_all_devices_for_user_lab(user_id=self.user.pk), 1)
        with self.assertRaises(Exception):
            validate_access(old_tokens[0])
        new_mode, new_tokens = begin_native_login_lab(self.user.username, PASSWORD)
        self.assertEqual(new_mode, "ready")
        self.assertEqual(validate_access(new_tokens[0]).pk, self.user.pk)

    def test_forged_challenge_cannot_complete_mfa(self):
        self.enable_mfa()
        raw = self.challenge()
        forged = raw[:-1] + ("B" if raw[-1] != "B" else "C")
        with self.assertRaises(NativeLoginLabDenied):
            self.valid_mfa(forged)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())
