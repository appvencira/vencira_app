"""S1: factor rotation safety checks (synthetic accounts)."""
from django.test import TestCase
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
