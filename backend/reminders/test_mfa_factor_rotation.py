"""S1: factor rotation safety checks (synthetic accounts)."""
from django.test import TestCase
from django.utils import timezone
from cryptography.fernet import Fernet
from .mfa_secrets import encrypt_totp_secret, decrypt_totp_secret
from .mfa_totp import generate_secret, totp_at
from .models import UserMfaRecoveryCode
from django.contrib.auth import get_user_model
from .models import UserMfaState
from .mfa_factor_rotation import prepare_factor_rotation, confirm_factor_rotation


class RotationFailClosedTests(TestCase):
    def test_disabled_account_cannot_rotate(self):
        user = get_user_model().objects.create_user("rotation_disabled")
        state = UserMfaState.objects.create(user=user, enabled=False, encrypted_totp_secret="")
        self.assertIsNone(prepare_factor_rotation(user_id=user.pk, old_code="000000", keys=[]))
        self.assertIsNone(confirm_factor_rotation(user_id=user.pk, new_code="000000", keys=[]))
        state.refresh_from_db()
        self.assertFalse(state.enabled)
        self.assertEqual(state.session_epoch, 0)

    def test_rotation_keeps_old_factor_until_verified_then_revokes_sessions(self):
        user = get_user_model().objects.create_user("rotation_active")
        keys = [Fernet.generate_key().decode("ascii")]
        old_secret = generate_secret()
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(
                old_secret, user_id=user.pk, keys=keys,
            ),
        )
        instant = int(timezone.now().timestamp())
        original = state.encrypted_totp_secret
        prepared = prepare_factor_rotation(
            user_id=user.pk, old_code=totp_at(old_secret, instant),
            keys=keys, timestamp=instant,
        )
        self.assertIsNotNone(prepared)
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, original)
        self.assertTrue(state.enabled)
        self.assertIsNone(confirm_factor_rotation(
            user_id=user.pk, new_code="invalid", keys=keys, timestamp=instant,
        ))
        state.refresh_from_db()
        self.assertEqual(state.session_epoch, 0)
        codes = confirm_factor_rotation(
            user_id=user.pk, new_code=totp_at(prepared, instant),
            keys=keys, timestamp=instant,
        )
        self.assertEqual(len(codes), 10)
        state.refresh_from_db()
        self.assertEqual(state.session_epoch, 1)
        self.assertTrue(state.enabled)
        self.assertEqual(state.pending_rotation_secret, "")
        self.assertEqual(decrypt_totp_secret(
            state.encrypted_totp_secret, user_id=user.pk, keys=keys,
        ), prepared)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=state).count(), 10)
        self.assertIsNone(confirm_factor_rotation(
            user_id=user.pk, new_code=totp_at(prepared, instant),
            keys=keys, timestamp=instant,
        ))

    def test_invalid_old_factor_attempts_are_rate_limited(self):
        from datetime import timedelta
        from django.utils import timezone
        from cryptography.fernet import Fernet
        from .mfa_secrets import encrypt_totp_secret
        from .mfa_totp import generate_secret
        user = get_user_model().objects.create_user("rotation_throttle")
        keys = [Fernet.generate_key().decode("ascii")]
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(
                generate_secret(), user_id=user.pk, keys=keys,
            ),
        )
        for _ in range(5):
            self.assertIsNone(prepare_factor_rotation(
                user_id=user.pk, old_code="invalid", keys=keys,
            ))
        state.refresh_from_db()
        self.assertEqual(state.failed_attempts, 5)
        self.assertGreater(state.locked_until, timezone.now())
        self.assertEqual(state.pending_rotation_secret, "")
