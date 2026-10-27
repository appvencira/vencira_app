"""S1: factor rotation safety checks (synthetic accounts)."""
from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from cryptography.fernet import Fernet
from .mfa_secrets import encrypt_totp_secret, decrypt_totp_secret, hash_recovery_code
from .mfa_totp import generate_secret, totp_at
from .models import UserMfaRecoveryCode, UserMfaPendingRotationCode
from django.contrib.auth import get_user_model
from .models import UserMfaState
from .mfa_factor_rotation import prepare_factor_rotation, confirm_factor_rotation, finalize_factor_rotation


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
        self.assertEqual(state.session_epoch, 0)
        self.assertEqual(state.encrypted_totp_secret, original)
        self.assertEqual(UserMfaPendingRotationCode.objects.filter(state=state).count(), 10)
        self.assertFalse(finalize_factor_rotation(user_id=user.pk, proof_code="invalid", keys=keys))
        state.refresh_from_db()
        self.assertEqual(state.session_epoch, 0)
        self.assertEqual(state.encrypted_totp_secret, original)
        self.assertTrue(finalize_factor_rotation(user_id=user.pk, proof_code=codes[0], keys=keys))
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

    def test_lost_delivery_and_expiration_preserve_original_recovery(self):
        user = get_user_model().objects.create_user("rotation_lost_delivery")
        keys = [Fernet.generate_key().decode("ascii")]
        old_secret = generate_secret()
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(old_secret, user_id=user.pk, keys=keys),
        )
        original_hash = hash_recovery_code("A" * 32)
        UserMfaRecoveryCode.objects.create(state=state, code_hash=original_hash)
        original = state.encrypted_totp_secret
        instant = int(timezone.now().timestamp())
        prepared = prepare_factor_rotation(
            user_id=user.pk, old_code=totp_at(old_secret, instant),
            keys=keys, timestamp=instant,
        )
        self.assertIsNotNone(prepared)
        provisional = confirm_factor_rotation(
            user_id=user.pk, new_code=totp_at(prepared, instant),
            keys=keys, timestamp=instant,
        )
        self.assertEqual(len(provisional), 10)
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, original)
        self.assertEqual(state.session_epoch, 0)
        self.assertEqual(
            list(UserMfaRecoveryCode.objects.filter(state=state).values_list("code_hash", flat=True)),
            [original_hash],
        )
        state.pending_rotation_expires_at = timezone.now() - timedelta(seconds=1)
        state.save(update_fields=["pending_rotation_expires_at"])
        self.assertFalse(finalize_factor_rotation(user_id=user.pk, proof_code=provisional[0], keys=keys))
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, original)
        self.assertEqual(state.session_epoch, 0)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=state).count(), 1)

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

    def test_locked_confirmation_never_replaces_factor(self):
        from datetime import timedelta
        from django.utils import timezone
        from cryptography.fernet import Fernet
        from .mfa_secrets import encrypt_totp_secret
        from .mfa_totp import generate_secret
        user = get_user_model().objects.create_user("rotation_locked_confirmation")
        keys = [Fernet.generate_key().decode("ascii")]
        active = encrypt_totp_secret(generate_secret(), user_id=user.pk, keys=keys)
        pending = encrypt_totp_secret(generate_secret(), user_id=user.pk, keys=keys)
        state = UserMfaState.objects.create(
            user=user, enabled=True, encrypted_totp_secret=active,
            pending_rotation_secret=pending,
            pending_rotation_expires_at=timezone.now() + timedelta(minutes=10),
            locked_until=timezone.now() + timedelta(minutes=15),
        )
        self.assertIsNone(confirm_factor_rotation(
            user_id=user.pk, new_code="000000", keys=keys
        ))
        state.refresh_from_db()
        self.assertEqual(state.encrypted_totp_secret, active)
        self.assertEqual(state.pending_rotation_secret, pending)
        self.assertEqual(state.session_epoch, 0)

    def test_pending_recovery_blocks_normal_rotation(self):
        from .models import MfaAdministrativeRecoveryCase
        user = get_user_model().objects.create_user("rotation_pending_case")
        keys = [Fernet.generate_key().decode("ascii")]
        secret = generate_secret()
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(secret, user_id=user.pk, keys=keys),
        )
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=user, requester=user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        instant = int(now.timestamp())
        self.assertIsNone(prepare_factor_rotation(
            user_id=user.pk, old_code=totp_at(secret, instant),
            keys=keys, timestamp=instant,
        ))
        state.refresh_from_db()
        self.assertEqual(state.pending_rotation_secret, "")
        self.assertEqual(state.session_epoch, 0)

    def test_recovery_pending_blocks_staged_confirmation_and_finalization(self):
        from .models import MfaAdministrativeRecoveryCase, UserMfaPendingRotationCode
        from .mfa_factor_rotation import finalize_factor_rotation
        user = get_user_model().objects.create_user("rotation_interrupted")
        keys = [Fernet.generate_key().decode("ascii")]
        old_secret = generate_secret()
        new_secret = generate_secret()
        state = UserMfaState.objects.create(
            user=user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(old_secret, user_id=user.pk, keys=keys),
            pending_rotation_secret=encrypt_totp_secret(new_secret, user_id=user.pk, keys=keys),
            pending_rotation_expires_at=timezone.now() + timedelta(minutes=10),
        )
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=user, requester=user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        code = "A" * 32
        UserMfaPendingRotationCode.objects.create(state=state, code_hash=hash_recovery_code(code))
        instant = int(now.timestamp())
        self.assertIsNone(confirm_factor_rotation(
            user_id=user.pk, new_code=totp_at(new_secret, instant),
            keys=keys, timestamp=instant,
        ))
        self.assertFalse(finalize_factor_rotation(user_id=user.pk, proof_code=code, keys=keys))
        state.refresh_from_db()
        self.assertEqual(decrypt_totp_secret(
            state.encrypted_totp_secret, user_id=user.pk, keys=keys,
        ), old_secret)
        self.assertEqual(state.session_epoch, 0)
