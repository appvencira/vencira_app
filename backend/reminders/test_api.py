"""Pruebas de autorización, aislamiento, validación y CSRF."""
from datetime import date

from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from .models import Renewal, Workspace, WorkspaceMember


class ScopedRenewalApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner_a = get_user_model().objects.create_user(
            username="propietario_a", password="LocalOnlyPasswordA!2026"
        )
        cls.member_a = get_user_model().objects.create_user(
            username="miembro_a", password="LocalOnlyPasswordB!2026"
        )
        cls.owner_b = get_user_model().objects.create_user(
            username="propietario_b", password="LocalOnlyPasswordC!2026"
        )
        cls.unassigned = get_user_model().objects.create_user(
            username="sin_equipo", password="LocalOnlyPasswordD!2026"
        )
        cls.workspace_a = Workspace.objects.create(name="Correduría A")
        cls.workspace_b = Workspace.objects.create(name="Correduría B")
        WorkspaceMember.objects.create(workspace=cls.workspace_a, user=cls.owner_a, role=WorkspaceMember.Role.OWNER)
        WorkspaceMember.objects.create(workspace=cls.workspace_a, user=cls.member_a, role=WorkspaceMember.Role.MEMBER)
        WorkspaceMember.objects.create(workspace=cls.workspace_b, user=cls.owner_b, role=WorkspaceMember.Role.OWNER)
        cls.renewal_a = Renewal.objects.create(
            workspace=cls.workspace_a, customer_reference="TEST-A", expires_on=date(2027, 4, 10)
        )
        cls.renewal_b = Renewal.objects.create(
            workspace=cls.workspace_b, customer_reference="TEST-B", expires_on=date(2027, 5, 10)
        )

    @classmethod
    def list_url(cls, workspace):
        return reverse("api-renewals", kwargs={"workspace_id": workspace.id})

    @classmethod
    def detail_url(cls, workspace, renewal):
        return reverse("api-renewal-detail", kwargs={"workspace_id": workspace.id, "renewal_id": renewal.id})

    def test_anonymous_denied_all_business_routes(self):
        urls = [
            reverse("api-me"), reverse("api-workspaces"),
            self.list_url(self.workspace_a), self.detail_url(self.workspace_a, self.renewal_a)
        ]
        for url in urls:
            with self.subTest(url=url):
                self.assertIn(self.client.get(url).status_code, (401, 403))
        self.assertIn(self.client.post(self.list_url(self.workspace_a),
            {"customer_reference": "X", "expires_on": "2027-05-01"}, format="json").status_code, (401, 403))

    def test_workspaces_only_user_memberships(self):
        self.client.force_authenticate(user=self.owner_a)
        response = self.client.get(reverse("api-workspaces"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(str(response.data[0]["id"]), str(self.workspace_a.id))
        self.assertEqual(response.data[0]["role"], "owner")
        self.assertEqual(self.client.get(reverse("api-me")).data["username"], "propietario_a")

    def test_member_can_read_and_update_own_workspace(self):
        self.client.force_authenticate(user=self.member_a)
        list_response = self.client.get(self.list_url(self.workspace_a))
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(list_response.data["count"], 1)
        self.assertEqual(list_response.data["results"][0]["customer_reference"], "TEST-A")
        detail_response = self.client.patch(
            self.detail_url(self.workspace_a, self.renewal_a), {"status": "contacted"}, format="json"
        )
        self.assertEqual(detail_response.status_code, 200)
        self.renewal_a.refresh_from_db()
        self.assertEqual(self.renewal_a.status, "contacted")

    def test_cannot_see_or_mutate_other_workspace(self):
        self.client.force_authenticate(user=self.owner_a)
        self.assertEqual(self.client.get(self.list_url(self.workspace_b)).status_code, 404)
        self.assertEqual(self.client.get(self.detail_url(self.workspace_b, self.renewal_b)).status_code, 404)
        self.assertEqual(self.client.patch(
            self.detail_url(self.workspace_b, self.renewal_b), {"status": "closed"}, format="json"
        ).status_code, 404)
        self.assertEqual(self.client.post(
            self.list_url(self.workspace_b), {"customer_reference": "HACK", "expires_on": "2027-01-01"}, format="json"
        ).status_code, 404)
        # Incluso pasando el identificador ajeno bajo la ruta del workspace propio.
        self.assertEqual(self.client.get(self.detail_url(self.workspace_a, self.renewal_b)).status_code, 404)
        self.renewal_b.refresh_from_db()
        self.assertEqual(self.renewal_b.status, "pending")

    def test_authenticated_user_without_membership_is_denied(self):
        self.client.force_authenticate(user=self.unassigned)
        self.assertEqual(self.client.get(reverse("api-workspaces")).data, [])
        self.assertEqual(self.client.get(self.list_url(self.workspace_a)).status_code, 404)

    def test_create_scoped_and_prevent_tenant_forgery(self):
        self.client.force_authenticate(user=self.owner_a)
        url = self.list_url(self.workspace_a)
        forbidden = self.client.post(url, {
            "customer_reference": "INTENTO", "expires_on": "2027-01-01",
            "workspace": str(self.workspace_b.id),
        }, format="json")
        self.assertEqual(forbidden.status_code, 400)
        success = self.client.post(url, {
            "customer_reference": "NUEVO", "expires_on": "2027-06-10", "status": "pending"
        }, format="json")
        self.assertEqual(success.status_code, 201)
        item = Renewal.objects.get(pk=success.data["id"])
        self.assertEqual(item.workspace_id, self.workspace_a.id)
        self.assertNotIn("workspace", success.data)
        # No se puede desplazar el objeto a otra organización.
        transfer = self.client.patch(self.detail_url(self.workspace_a, item), {
            "workspace_id": str(self.workspace_b.id)
        }, format="json")
        self.assertEqual(transfer.status_code, 400)
        item.refresh_from_db()
        self.assertEqual(item.workspace_id, self.workspace_a.id)

    def test_validation_and_methods(self):
        self.client.force_authenticate(user=self.owner_a)
        invalid = self.client.post(self.list_url(self.workspace_a), {
            "customer_reference": "", "expires_on": "imposible"
        }, format="json")
        self.assertEqual(invalid.status_code, 400)
        self.assertEqual(self.client.delete(self.detail_url(self.workspace_a, self.renewal_a)).status_code, 405)
        self.assertEqual(self.client.put(self.detail_url(self.workspace_a, self.renewal_a), {
            "status": "closed"
        }, format="json").status_code, 405)

    def test_bounded_pagination(self):
        self.client.force_authenticate(user=self.owner_a)
        response = self.client.get(self.list_url(self.workspace_a) + "?page_size=1")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data["results"]), 1)

    def test_session_authentication_rejects_missing_csrf_on_write(self):
        client = APIClient(enforce_csrf_checks=True)
        client.force_login(self.owner_a)
        url = self.list_url(self.workspace_a)
        denied = client.post(url, {
            "customer_reference": "CSRF", "expires_on": "2027-01-01"
        }, format="json")
        self.assertEqual(denied.status_code, 403)
        page = client.get(reverse("login"))
        self.assertEqual(page.status_code, 200)
        csrf = client.cookies["csrftoken"].value
        allowed = client.post(url, {
            "customer_reference": "CSRF", "expires_on": "2027-01-01"
        }, format="json", HTTP_X_CSRFTOKEN=csrf)
        self.assertEqual(allowed.status_code, 201)

    def test_login_and_logout_browser_flow(self):
        client = Client(enforce_csrf_checks=True)
        page = client.get(reverse("login"))
        self.assertEqual(page.status_code, 200)
        csrf = client.cookies["csrftoken"].value
        logged = client.post(reverse("login"), {
            "username": "propietario_a", "password": "LocalOnlyPasswordA!2026",
            "csrfmiddlewaretoken": csrf,
        })
        self.assertEqual(logged.status_code, 302)
        self.assertEqual(client.get(reverse("api-me")).status_code, 200)
        self.assertEqual(client.get(reverse("logout")).status_code, 405)
        out = client.post(reverse("logout"), HTTP_X_CSRFTOKEN=client.cookies["csrftoken"].value)
        self.assertEqual(out.status_code, 302)
        self.assertIn(client.get(reverse("api-me")).status_code, (401, 403))
