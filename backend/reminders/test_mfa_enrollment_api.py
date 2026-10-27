"""D1.5k: alta MFA por API bajo feature flag apagado por defecto."""
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import Client, TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from .mfa_totp import totp_at
from .models import UserMfaRecoveryCode, UserMfaState


class EnrollmentApiTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="mfa_setup_demo", password="LocalOnlyPassword!2026",
        )
        self.client = Client()
        self.client.force_login(self.user)
        self.key = Fernet.generate_key().decode("ascii")

    def test_disabled_by_default_even_for_authenticated_user(self):
        self.assertEqual(
            self.client.post(reverse("api-mfa-setup-start"), data={"password": "x"},
                             content_type="application/json").status_code, 404,
        )
        self.assertFalse(UserMfaState.objects.filter(user=self.user).exists())

    @override_settings(VENCIRA_MFA_ENROLLMENT_ENABLED=True)
    def test_reauthentication_then_totp_confirmation_only_once(self):
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": self.key}):
            url = reverse("api-mfa-setup-start")
            self.assertEqual(self.client.post(
                url, data={"password": "wrong"}, content_type="application/json",
            ).status_code, 403)
            self.assertFalse(UserMfaState.objects.filter(user=self.user).exists())
            response = self.client.post(
                url, data={"password": "LocalOnlyPassword!2026"},
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 200)
            payload = response.json()
            self.assertIn("otpauth://totp/", payload["provisioning_uri"])
            self.assertFalse(UserMfaState.objects.get(user=self.user).enabled)
            confirm = reverse("api-mfa-setup-confirm")
            invalid = self.client.post(
                confirm, data={"code": "INVALID"}, content_type="application/json",
            )
            self.assertEqual(invalid.status_code, 403)
            valid = self.client.post(
                confirm,
                data={"code": totp_at(payload["secret"], int(timezone.now().timestamp()))},
                content_type="application/json",
            )
            self.assertEqual(valid.status_code, 200)
            self.assertEqual(len(valid.json()["recovery_codes"]), 10)
            self.assertEqual(UserMfaRecoveryCode.objects.filter(
                state__user=self.user,
            ).count(), 10)
            self.assertTrue(UserMfaState.objects.get(user=self.user).enabled)
            self.assertEqual(self.client.get(reverse("api-me")).status_code, 200)
            again = self.client.post(
                confirm, data={"code": "000000"}, content_type="application/json",
            )
            self.assertEqual(again.status_code, 409)

    @override_settings(VENCIRA_MFA_ENROLLMENT_ENABLED=True)
    def test_invalid_key_never_prepares_secret(self):
        with patch.dict("os.environ", {"VENCIRA_MFA_FERNET_KEYS": ""}):
            response = self.client.post(
                reverse("api-mfa-setup-start"),
                data={"password": "LocalOnlyPassword!2026"},
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 503)
            self.assertFalse(UserMfaState.objects.filter(user=self.user).exists())
