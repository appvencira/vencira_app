"""Isolated ORM tests. Only run with VENCIRA_NATIVE_SESSION_LAB=1."""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from reminders.models import UserMfaState
from reminders.native_mobile_token_primitives import make_native_token
from .models import MobileDeviceSessionLab, SpentRefreshLab
from .session_rules import (
    SessionLabDenied, issue_verified_session, validate_access,
    rotate_refresh, revoke_device,
)


class DeviceLifecycleTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="n1-lab-synthetic",
            password="UnitTestOnlyStrongPassword-01",
        )

    def issue(self):
        return issue_verified_session(
            user=self.user, verified_mfa=False, mfa_epoch=None)

    def test_issue_and_validate_access(self):
        access, refresh = self.issue()
        self.assertEqual(validate_access(access).pk, self.user.pk)
        self.assertFalse(refresh in access)
        row = MobileDeviceSessionLab.objects.get()
        self.assertNotIn(access, (row.access_digest, row.refresh_digest))
        self.assertNotIn(refresh, (row.access_digest, row.refresh_digest))

    def test_refresh_rotates_both_credentials_once(self):
        old_access, old_refresh = self.issue()
        new_access, new_refresh = rotate_refresh(old_refresh)
        self.assertNotEqual((old_access, old_refresh), (new_access, new_refresh))
        with self.assertRaises(SessionLabDenied):
            validate_access(old_access)
        self.assertEqual(validate_access(new_access).pk, self.user.pk)
        self.assertEqual(MobileDeviceSessionLab.objects.get().generation, 1)
        self.assertEqual(SpentRefreshLab.objects.count(), 1)

    def test_replay_of_used_refresh_revokes_entire_device(self):
        _, first = self.issue()
        new_access, new_refresh = rotate_refresh(first)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(first)
        with self.assertRaises(SessionLabDenied):
            validate_access(new_access)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(new_refresh)
        self.assertIsNotNone(MobileDeviceSessionLab.objects.get().revoked_at)

    def test_forged_refresh_does_not_revoke_another_session(self):
        valid_access, valid_refresh = self.issue()
        sid = MobileDeviceSessionLab.objects.get().pk
        forgery = make_native_token(kind="r", session_id=sid)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(forgery)
        self.assertEqual(validate_access(valid_access).pk, self.user.pk)
        self.assertIsNotNone(rotate_refresh(valid_refresh))

    def test_logout_is_isolated_to_current_device(self):
        access_a, refresh_a = self.issue()
        access_b, refresh_b = self.issue()
        revoke_device(refresh_a)
        with self.assertRaises(SessionLabDenied):
            validate_access(access_a)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh_a)
        self.assertEqual(validate_access(access_b).pk, self.user.pk)
        self.assertIsNotNone(rotate_refresh(refresh_b))

    def test_password_change_invalidates_access_and_refresh(self):
        access, refresh = self.issue()
        self.user.set_password("RotatedUnitTestOnlyPassword-02")
        self.user.save(update_fields=["password"])
        with self.assertRaises(SessionLabDenied):
            validate_access(access)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh)

    def test_inactive_user_is_denied(self):
        access, refresh = self.issue()
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(SessionLabDenied):
            validate_access(access)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh)

    def test_expiration_and_type_boundaries(self):
        access, refresh = self.issue()
        row = MobileDeviceSessionLab.objects.get()
        row.access_expires_at = timezone.now() - timedelta(seconds=1)
        row.save(update_fields=["access_expires_at"])
        with self.assertRaises(SessionLabDenied):
            validate_access(access)
        with self.assertRaises(SessionLabDenied):
            validate_access(refresh)
        row.refresh_expires_at = timezone.now() - timedelta(seconds=1)
        row.save(update_fields=["refresh_expires_at"])
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh)

    def test_mfa_epoch_change_denies_old_session(self):
        state = UserMfaState.objects.create(
            user=self.user, encrypted_totp_secret="synthetic-only",
            enabled=True, session_epoch=10,
        )
        access, refresh = issue_verified_session(
            user=self.user, verified_mfa=True, mfa_epoch=10)
        self.assertEqual(validate_access(access).pk, self.user.pk)
        state.session_epoch = 11
        state.save(update_fields=["session_epoch"])
        with self.assertRaises(SessionLabDenied):
            validate_access(access)
        with self.assertRaises(SessionLabDenied):
            rotate_refresh(refresh)

    def test_disabled_mfa_cannot_claim_completed_factor(self):
        with self.assertRaises(SessionLabDenied):
            issue_verified_session(
                user=self.user, verified_mfa=True, mfa_epoch=10)
