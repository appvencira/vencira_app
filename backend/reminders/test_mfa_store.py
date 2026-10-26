"""D1.5c: pruebas DB transaccional, sin uso por el login."""
from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import TestCase

from .mfa_secrets import encrypt_totp_secret, generate_recovery_codes, hash_recovery_code
from .mfa_store import consume_recovery_code, consume_totp
from .mfa_totp import generate_secret, totp_at
from .models import UserMfaRecoveryCode, UserMfaState


class MfaStoreTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="mfa_store_demo", password="LocalOnlyPassword!2026",
        )
        self.keys = [Fernet.generate_key().decode("ascii")]
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=False,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def test_totp_disabled_then_single_use_then_next_period(self):
        first = totp_at(self.secret, 300000)
        self.assertFalse(consume_totp(self.user.pk, first, keys=self.keys, timestamp=300000))
        self.state.enabled = True
        self.state.save(update_fields=["enabled"])
        self.assertTrue(consume_totp(self.user.pk, first, keys=self.keys, timestamp=300000))
        self.assertFalse(consume_totp(self.user.pk, first, keys=self.keys, timestamp=300000))
        self.assertFalse(consume_totp(self.user.pk, first, keys=self.keys, timestamp=300030))
        self.assertTrue(consume_totp(
            self.user.pk, totp_at(self.secret, 300060),
            keys=self.keys, timestamp=300060,
        ))

    def test_recovery_consumed_once_without_affecting_other_codes(self):
        codes = generate_recovery_codes()
        UserMfaRecoveryCode.objects.bulk_create([
            UserMfaRecoveryCode(state=self.state, code_hash=hash_recovery_code(code))
            for code in codes[:2]
        ])
        self.assertFalse(consume_recovery_code(self.user.pk, codes[0]))
        self.state.enabled = True
        self.state.save(update_fields=["enabled"])
        self.assertTrue(consume_recovery_code(self.user.pk, codes[0]))
        self.assertFalse(consume_recovery_code(self.user.pk, codes[0]))
        self.assertTrue(consume_recovery_code(self.user.pk, codes[1]))
        self.assertFalse(UserMfaRecoveryCode.objects.filter(state=self.state).exists())

    def test_failed_attempts_shared_between_totp_and_recovery_and_lock(self):
        from datetime import timedelta
        from django.utils import timezone
        self.state.enabled = True
        self.state.save(update_fields=["enabled"])
        code = generate_recovery_codes()[0]
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code(code),
        )
        for _ in range(3):
            self.assertFalse(consume_totp(self.user.pk, "nototp", keys=self.keys))
        for _ in range(2):
            self.assertFalse(consume_recovery_code(self.user.pk, "INVALID"))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 5)
        self.assertGreater(self.state.locked_until, timezone.now())
        self.assertFalse(consume_recovery_code(self.user.pk, code))
        self.assertTrue(UserMfaRecoveryCode.objects.filter(state=self.state).exists())
        self.state.locked_until = timezone.now() - timedelta(seconds=1)
        self.state.attempts_started_at = timezone.now() - timedelta(minutes=16)
        self.state.save(update_fields=["locked_until", "attempts_started_at"])
        self.assertTrue(consume_recovery_code(self.user.pk, code))
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 0)
        self.assertIsNone(self.state.locked_until)

    def test_other_account_cannot_consume_codes(self):
        code = generate_recovery_codes()[0]
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code(code),
        )
        other = get_user_model().objects.create_user(
            username="other_mfa_demo", password="LocalOnlyPassword!2026",
        )
        self.state.enabled = True
        self.state.save(update_fields=["enabled"])
        self.assertFalse(consume_recovery_code(other.pk, code))
        self.assertTrue(consume_recovery_code(self.user.pk, code))
