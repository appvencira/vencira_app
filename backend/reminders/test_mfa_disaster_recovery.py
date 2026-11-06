"""D1.5r: restore drill exclusively in isolated test DB, no operational keys."""
from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from .mfa_enrollment import prepare_mfa, confirm_mfa, finalize_mfa
from .mfa_secrets import decrypt_totp_secret, rotate_totp_secret
from .mfa_totp import totp_at
from .models import UserMfaState


class DisasterRecoveryDrill(TestCase):
    def test_ciphertext_restore_and_rotation_preserve_second_factor(self):
        user = get_user_model().objects.create_user(
            username="disaster_restore_demo", password="LocalOnlyPassword!2026",
        )
        original = Fernet.generate_key().decode("ascii")
        replacement = Fernet.generate_key().decode("ascii")
        secret, _ = prepare_mfa(user, keys=[original])
        timestamp = int(timezone.now().timestamp())
        codes = confirm_mfa(user.pk, totp_at(secret, timestamp),
                            keys=[original], timestamp=timestamp)
        self.assertIsNotNone(codes)
        self.assertTrue(finalize_mfa(user.pk, codes[0], issued_at=timestamp))
        state = UserMfaState.objects.get(user=user)
        self.assertTrue(state.enabled)
        restored_ciphertext = state.encrypted_totp_secret

        # Clon de recuperación: el ciphertext depende de la custodia externa.
        self.assertEqual(decrypt_totp_secret(
            restored_ciphertext, user_id=user.pk, keys=[original],
        ), secret)
        rotated = rotate_totp_secret(
            restored_ciphertext, user_id=user.pk,
            old_keys=[original], new_keys=[replacement],
        )
        self.assertEqual(decrypt_totp_secret(
            rotated, user_id=user.pk, keys=[replacement],
        ), secret)
        with self.assertRaises(ValueError):
            decrypt_totp_secret(rotated, user_id=user.pk, keys=[original])
        self.assertTrue(UserMfaState.objects.get(user=user).enabled)

    def test_missing_custody_key_fails_closed(self):
        user = get_user_model().objects.create_user(
            username="lost_custody_demo", password="LocalOnlyPassword!2026",
        )
        key = Fernet.generate_key().decode("ascii")
        unknown = Fernet.generate_key().decode("ascii")
        secret, _ = prepare_mfa(user, keys=[key])
        state = UserMfaState.objects.get(user=user)
        with self.assertRaises(ValueError):
            decrypt_totp_secret(
                state.encrypted_totp_secret, user_id=user.pk, keys=[unknown],
            )
        self.assertFalse(state.enabled)
        self.assertTrue(secret)
