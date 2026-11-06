"""El login protege las cuentas aun con varios workers Django."""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import reverse
from django.utils import timezone

from .login_security import MAX_FAILURES, _key
from .models import LoginAttemptBucket


class ProtectedLoginTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="Demo_A", password="PasswordLocalOnly!2026",
        )
        cls.other = get_user_model().objects.create_user(
            username="Demo_B", password="PasswordLocalOnly!2026",
        )

    def test_successful_login_works_and_clears_failures(self):
        client = Client()
        url = reverse("login")
        self.assertEqual(client.get(url).status_code, 200)
        for _ in range(2):
            self.assertEqual(client.post(url, {"username": "Demo_A", "password": "incorrecta"}).status_code, 200)
        self.assertEqual(LoginAttemptBucket.objects.get(pk=_key("Demo_A")).failures, 2)
        self.assertEqual(client.post(url, {"username": "Demo_A", "password": "PasswordLocalOnly!2026"}).status_code, 302)
        self.assertFalse(LoginAttemptBucket.objects.filter(pk=_key("Demo_A")).exists())

    def test_blocks_after_max_failures_but_not_unrelated_account(self):
        url = reverse("login")
        for _ in range(MAX_FAILURES):
            self.assertEqual(self.client.post(url, {"username": "Demo_A", "password": "nope"}).status_code, 200)
        locked = self.client.post(url, {"username": "Demo_A", "password": "PasswordLocalOnly!2026"})
        self.assertEqual(locked.status_code, 429)
        self.assertEqual(locked["Cache-Control"], "no-store")
        other = self.client.post(url, {"username": "Demo_B", "password": "PasswordLocalOnly!2026"})
        self.assertEqual(other.status_code, 302)

    def test_expired_block_allows_attempt_and_resets_window(self):
        url = reverse("login")
        for _ in range(MAX_FAILURES):
            self.client.post(url, {"username": "Demo_A", "password": "wrong"})
        LoginAttemptBucket.objects.filter(pk=_key("Demo_A")).update(
            started_at=timezone.now() - timedelta(hours=1),
            blocked_until=timezone.now() - timedelta(minutes=1),
        )
        response = self.client.post(url, {"username": "Demo_A", "password": "PasswordLocalOnly!2026"})
        self.assertEqual(response.status_code, 302)
        self.assertFalse(LoginAttemptBucket.objects.filter(pk=_key("Demo_A")).exists())

    def test_unknown_user_is_also_limited(self):
        url = reverse("login")
        for _ in range(MAX_FAILURES):
            self.client.post(url, {"username": "noexiste", "password": "incorrecta"})
        self.assertEqual(
            self.client.post(url, {"username": "noexiste", "password": "incorrecta"}).status_code, 429
        )
        self.assertFalse(LoginAttemptBucket.objects.filter(pk=_key("noexiste")).exists() is True and
                         LoginAttemptBucket.objects.get(pk=_key("noexiste")).failures < MAX_FAILURES)
