"""D1.5f: MFA preauth no crea sesión hasta segundo factor."""
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import reverse

from .mfa_secrets import encrypt_totp_secret, hash_recovery_code
from .mfa_totp import generate_secret, totp_at
from .models import UserMfaRecoveryCode, UserMfaState


class MfaLoginTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="mfa_login_demo", password="LocalOnlyPassword!2026",
        )
        self.key = Fernet.generate_key().decode("ascii")
        self.secret = generate_secret()
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=[self.key],
            ),
        )

    def _password_step(self, browser):
        response = browser.post(reverse("login"), {
            "username": "mfa_login_demo",
            "password": "LocalOnlyPassword!2026",
        })
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, reverse("mfa-challenge"))
        self.assertIn(browser.get(reverse("api-me")).status_code, (401, 403))

    def test_totp_required_and_session_created_only_after_valid_second_factor(self):
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": self.key}):
            browser = Client()
            self._password_step(browser)
            self.assertEqual(browser.get(reverse("mfa-challenge")).status_code, 200)
            self.assertEqual(browser.post(reverse("mfa-challenge"), {"code": "000000"}).status_code, 403)
            self.assertIn(browser.get(reverse("api-me")).status_code, (401, 403))
            from django.utils import timezone
            code = totp_at(self.secret, int(timezone.now().timestamp()))
            response = browser.post(reverse("mfa-challenge"), {"code": code})
            self.assertEqual(response.status_code, 302)
            self.assertEqual(browser.get(reverse("api-me")).status_code, 200)
            self.assertNotEqual(browser.post(reverse("mfa-challenge"), {"code": code}).status_code, 302)

    def test_recovery_one_time_and_no_password_only_access(self):
        recovery = "A" * 32
        UserMfaRecoveryCode.objects.create(
            state=self.state, code_hash=hash_recovery_code(recovery),
        )
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": self.key}):
            browser = Client()
            self._password_step(browser)
            self.assertEqual(browser.post(reverse("mfa-challenge"), {"code": recovery}).status_code, 302)
            browser2 = Client()
            self._password_step(browser2)
            self.assertEqual(browser2.post(reverse("mfa-challenge"), {"code": recovery}).status_code, 403)

    def test_no_key_fails_closed_and_cannot_reach_authenticated_session(self):
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": ""}):
            browser = Client()
            self._password_step(browser)
            self.assertEqual(browser.post(reverse("mfa-challenge"), {"code": "A" * 32}).status_code, 503)
            self.assertIn(browser.get(reverse("api-me")).status_code, (401, 403))

    def test_unenrolled_users_keep_password_login(self):
        self.state.delete()
        browser = Client()
        response = browser.post(reverse("login"), {
            "username": "mfa_login_demo",
            "password": "LocalOnlyPassword!2026",
        })
        self.assertEqual(response.status_code, 302)
        self.assertEqual(browser.get(reverse("api-me")).status_code, 200)
