"""D1.5e: pruebas del servicio interno, nunca conectadas al login."""
from datetime import timedelta

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from .mfa_enrollment import confirm_mfa, prepare_mfa, finalize_mfa
from .mfa_totp import totp_at
from .models import UserMfaRecoveryCode, UserMfaState


class InternalMfaEnrollmentTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="mfa_enroll_demo", password="LocalOnlyPassword!2026",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]

    def test_prepare_does_not_activate_and_confirmation_generates_recovery_once(self):
        secret, uri = prepare_mfa(self.user, keys=self.keys)
        self.assertIn("otpauth://totp/", uri)
        state = UserMfaState.objects.get(user=self.user)
        self.assertFalse(state.enabled)
        self.assertFalse(UserMfaRecoveryCode.objects.filter(state=state).exists())
        codes = confirm_mfa(self.user.pk, totp_at(secret, 300000),
                            keys=self.keys, timestamp=300000)
        self.assertIsNotNone(codes)
        self.assertEqual(len(codes), 10)
        state.refresh_from_db()
        self.assertFalse(state.enabled)
        self.assertEqual(state.last_accepted_counter, 10000)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=state).count(), 10)
        self.assertIsNone(confirm_mfa(self.user.pk, totp_at(secret, 300000),
                                       keys=self.keys, timestamp=300000))
        self.assertFalse(finalize_mfa(self.user.pk, 'INVALID', issued_at=int(timezone.now().timestamp())))
        self.assertTrue(finalize_mfa(self.user.pk, codes[0], issued_at=int(timezone.now().timestamp())))
        self.assertTrue(UserMfaState.objects.get(user=self.user).enabled)
        with self.assertRaises(ValueError):
            prepare_mfa(self.user, keys=self.keys)

    def test_invalid_confirmation_keeps_mfa_disabled(self):
        prepare_mfa(self.user, keys=self.keys)
        self.assertIsNone(confirm_mfa(self.user.pk, "invalid", keys=self.keys))
        self.assertFalse(UserMfaState.objects.get(user=self.user).enabled)

    def test_preparation_expiry_cannot_be_extended_by_failed_attempts(self):
        prepare_mfa(self.user, keys=self.keys)
        state = UserMfaState.objects.get(user=self.user)
        state.prepared_at = timezone.now() - timedelta(minutes=11)
        state.save(update_fields=["prepared_at"])
        self.assertIsNone(confirm_mfa(self.user.pk, "invalid", keys=self.keys))
        self.assertFalse(UserMfaState.objects.get(user=self.user).enabled)

    def test_second_preparation_rotates_secret_and_invalidates_first(self):
        old, _ = prepare_mfa(self.user, keys=self.keys)
        new, _ = prepare_mfa(self.user, keys=self.keys)
        self.assertNotEqual(old, new)
        self.assertFalse(UserMfaState.objects.get(user=self.user).enabled)
