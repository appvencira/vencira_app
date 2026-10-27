from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone
from .models import UserMfaState
from .mfa_challenge import PENDING_KEY


class EmergencyRecoveryLoginTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="emergency_login_test", password="Synthetic-Password-Only-2026!"
        )
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, encrypted_totp_secret="synthetic-only",
        )
        session = self.client.session
        session[PENDING_KEY] = {
            "user_id": self.user.pk,
            "backend": "django.contrib.auth.backends.ModelBackend",
            "issued": int(timezone.now().timestamp()),
            "next": "/api/v1/me/",
        }
        session.save()

    @patch("reminders.mfa_challenge.load_mfa_keys", return_value=["synthetic"])
    def test_recovery_code_is_one_use_and_revokes_existing_sessions(self, _keys):
        from .models import UserMfaRecoveryCode
        from .mfa_secrets import hash_recovery_code
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code("A" * 32),
        )
        response = self.client.post(reverse("mfa-challenge"), {"code": "A" * 32})
        self.assertEqual(response.status_code, 302)
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 1)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=self.state).count(), 0)
        self.assertEqual(self.client.session["vencira_mfa_session_epoch_v1"], 1)

    @patch("reminders.mfa_challenge.load_mfa_keys", return_value=["synthetic"])
    @patch("reminders.mfa_challenge.consume_totp", return_value=True)
    def test_totp_login_does_not_revoke_sessions(self, _consume, _keys):
        response = self.client.post(reverse("mfa-challenge"), {"code": "123456"})
        self.assertEqual(response.status_code, 302)
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 0)

    @patch("reminders.mfa_challenge.load_mfa_keys", return_value=["synthetic"])
    def test_malformed_attempts_count_and_lock_account(self, _keys):
        for _ in range(5):
            response = self.client.post(reverse("mfa-challenge"), {"code": "bad"})
            self.assertEqual(response.status_code, 403)
        self.state.refresh_from_db()
        self.assertEqual(self.state.failed_attempts, 5)
        self.assertIsNotNone(self.state.locked_until)
        self.assertGreater(self.state.locked_until, timezone.now())

    @patch("reminders.mfa_challenge.load_mfa_keys", return_value=["synthetic"])
    def test_locked_account_rejects_recovery_code_without_consumption(self, _keys):
        from .models import UserMfaRecoveryCode
        from .mfa_secrets import hash_recovery_code
        from datetime import timedelta
        self.state.locked_until = timezone.now() + timedelta(minutes=10)
        self.state.save(update_fields=["locked_until"])
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code("B" * 32),
        )
        response = self.client.post(reverse("mfa-challenge"), {"code": "B" * 32})
        self.assertEqual(response.status_code, 403)
        self.assertEqual(UserMfaRecoveryCode.objects.filter(state=self.state).count(), 1)
