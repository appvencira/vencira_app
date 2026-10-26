"""D1.3: cierre de otras sesiones reales sin alterar la sesión actual."""
from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import reverse


class LogoutOtherSessionsTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_user(
            username="session_owner", password="LocalOnlyPassword!2026",
        )
        cls.other = get_user_model().objects.create_user(
            username="session_other", password="LocalOnlyPassword!2026",
        )

    def test_requires_session_password_and_preserves_current_and_other_users(self):
        phone, desktop, stranger = Client(), Client(), Client()
        self.assertTrue(phone.login(username="session_owner", password="LocalOnlyPassword!2026"))
        self.assertTrue(desktop.login(username="session_owner", password="LocalOnlyPassword!2026"))
        self.assertTrue(stranger.login(username="session_other", password="LocalOnlyPassword!2026"))
        url = reverse("api-logout-other-sessions")
        self.assertIn(Client().post(url, {"password": "LocalOnlyPassword!2026"},
                                    content_type="application/json").status_code, (401, 403))
        self.assertEqual(phone.get(url).status_code, 405)
        self.assertEqual(phone.post(url, {"password": "wrong"}, content_type="application/json").status_code, 403)
        self.assertEqual(phone.post(url, {"unexpected": "x"}, content_type="application/json").status_code, 400)
        response = phone.post(url, {"password": "LocalOnlyPassword!2026"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"revoked": 1})
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(phone.get(reverse("api-me")).status_code, 200)
        self.assertIn(desktop.get(reverse("api-me")).status_code, (401, 403))
        self.assertEqual(stranger.get(reverse("api-me")).status_code, 200)
        self.assertEqual(phone.post(url, {"password": "LocalOnlyPassword!2026"},
                                    content_type="application/json").json(), {"revoked": 0})

    def test_rejects_write_without_csrf_on_authenticated_browser(self):
        browser = Client(enforce_csrf_checks=True)
        self.assertTrue(browser.login(username="session_owner", password="LocalOnlyPassword!2026"))
        response = browser.post(reverse("api-logout-other-sessions"),
                                {"password": "LocalOnlyPassword!2026"}, content_type="application/json")
        self.assertEqual(response.status_code, 403)
