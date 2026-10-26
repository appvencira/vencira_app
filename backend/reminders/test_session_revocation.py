"""D1.2: revocación global de acceso con sesiones Django reales.

Pruebas con datos sintéticos; no utilizan la base de datos persistente.
"""
from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.urls import reverse

from .models import Workspace, WorkspaceMember


class BrowserSessionRevocationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="d12_member", password="LocalOnlyPassword!2026",
        )
        cls.workspace_a = Workspace.objects.create(name="D12 organización A")
        cls.workspace_b = Workspace.objects.create(name="D12 organización B")
        for workspace in (cls.workspace_a, cls.workspace_b):
            WorkspaceMember.objects.create(
                workspace=workspace, user=cls.user, role=WorkspaceMember.Role.MEMBER,
            )

    def _two_devices(self):
        devices = (Client(), Client())
        for browser in devices:
            self.assertTrue(browser.login(
                username="d12_member", password="LocalOnlyPassword!2026",
            ))
            self.assertEqual(browser.get(reverse("api-me")).status_code, 200)
        return devices

    def test_workspace_membership_revocation_preserves_other_workspace_and_session(self):
        phone, desktop = self._two_devices()
        WorkspaceMember.objects.filter(
            workspace=self.workspace_a, user=self.user,
        ).delete()
        url_a = reverse("api-renewals", kwargs={"workspace_id": self.workspace_a.id})
        url_b = reverse("api-renewals", kwargs={"workspace_id": self.workspace_b.id})
        for browser in (phone, desktop):
            self.assertEqual(browser.get(url_a).status_code, 404)
            self.assertEqual(browser.get(url_b).status_code, 200)
            self.assertEqual(browser.get(reverse("api-me")).status_code, 200)

    def test_deactivating_account_denies_all_existing_browser_sessions(self):
        phone, desktop = self._two_devices()
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        for browser in (phone, desktop):
            self.assertIn(browser.get(reverse("api-me")).status_code, (401, 403))
            self.assertIn(browser.get(reverse("api-workspaces")).status_code, (401, 403))

    def test_password_reset_invalidates_existing_browser_sessions(self):
        phone, desktop = self._two_devices()
        self.user.set_password("RotatedLocalOnly!2026")
        self.user.save(update_fields=["password"])
        for browser in (phone, desktop):
            self.assertIn(browser.get(reverse("api-me")).status_code, (401, 403))
        fresh = Client()
        self.assertTrue(fresh.login(
            username="d12_member", password="RotatedLocalOnly!2026",
        ))
        self.assertEqual(fresh.get(reverse("api-me")).status_code, 200)
