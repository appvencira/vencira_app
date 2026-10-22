"""Catálogo de aseguradoras sin precarga regulatoria no verificada."""
from datetime import date
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from .models import Workspace, WorkspaceMember, WorkspaceInsurer, Renewal, RenewalAuditEvent


class InsurerCatalogTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.owner = User.objects.create_user(username="ins-owner")
        cls.member = User.objects.create_user(username="ins-member")
        cls.other = User.objects.create_user(username="ins-other")
        cls.ws = Workspace.objects.create(name="Empresa ficticia A")
        cls.foreign_ws = Workspace.objects.create(name="Empresa ficticia B")
        for user, workspace, role in (
            (cls.owner, cls.ws, "owner"),
            (cls.member, cls.ws, "member"),
            (cls.other, cls.foreign_ws, "owner"),
        ):
            WorkspaceMember.objects.create(
                workspace=workspace, user=user, role=role,
            )
        cls.first = WorkspaceInsurer.objects.create(
            workspace=cls.ws, name="Aseguradora Prueba A",
            normalized_name="aseguradora prueba a",
        )
        cls.second = WorkspaceInsurer.objects.create(
            workspace=cls.foreign_ws, name="Aseguradora Prueba B",
            normalized_name="aseguradora prueba b",
        )
        cls.legacy = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="POLIZA-FICTICIA", expires_on=date(2027, 4, 29),
            entry="clients", modality="hogar",
        )

    def listing(self, ws=None):
        return reverse("api-insurers", kwargs={"workspace_id": (ws or self.ws).id})

    def item(self, insurer=None, ws=None):
        return reverse("api-insurer-detail", kwargs={
            "workspace_id": (ws or self.ws).id,
            "insurer_id": (insurer or self.first).id,
        })

    def renewal(self):
        return reverse("api-renewal-detail", kwargs={
            "workspace_id": self.ws.id, "renewal_id": self.legacy.id,
        })

    def test_list_search_and_legacy_are_private(self):
        self.client.force_authenticate(user=self.member)
        response = self.client.get(self.listing() + "?q=prueba%20a")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual([row["name"] for row in response.data], ["Aseguradora Prueba A"])
        self.assertEqual(self.client.get(self.listing(self.foreign_ws)).status_code, 404)
        self.assertEqual(self.client.get(self.listing() + "?q=x" * 90).status_code, 400)
        self.assertIsNone(self.client.get(self.renewal()).data["insurer"])

    def test_owner_create_rename_soft_delete_preserves_references(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            self.listing(), {"name": "Prueba Seguros 2"}, format="json",
        )
        self.assertEqual(response.status_code, 201, response.data)
        identifier = response.data["id"]
        other = WorkspaceInsurer.objects.get(pk=identifier)
        self.assertEqual(
            self.client.post(self.listing(), {"name": "PRUEBA SEGUROS 2"}, format="json").status_code,
            409,
        )
        ren = self.client.patch(
            self.item(other), {"name": "Aseguradora de prueba 2"}, format="json",
        )
        self.assertEqual(ren.status_code, 200, ren.data)
        self.assertEqual(ren.data["id"], identifier)
        link = self.client.patch(self.renewal(), {"insurer": identifier}, format="json")
        self.assertEqual(link.status_code, 200, link.data)
        self.assertEqual(link.data["insurer"], identifier)
        self.assertEqual(self.client.delete(self.item(other)).status_code, 204)
        self.legacy.refresh_from_db()
        self.assertEqual(str(self.legacy.insurer_id), identifier)
        self.assertFalse(WorkspaceInsurer.objects.get(pk=identifier).active)
        # Un enlace antiguo puede conservar la referencia al cambiar estado.
        self.assertEqual(self.client.patch(
            self.renewal(), {"status": "contacted"}, format="json",
        ).status_code, 200)
        self.assertEqual(self.client.patch(
            self.renewal(), {"insurer": str(self.first.pk)}, format="json",
        ).status_code, 200)
        self.assertEqual(self.client.patch(
            self.item(other), {"active": True}, format="json",
        ).status_code, 200)

    def test_reject_foreign_inactive_and_mass_assignment(self):
        self.client.force_authenticate(user=self.owner)
        for payload in (
            {"insurer": str(self.second.pk)},
            {"insurer": "no-uuid"},
            {"insurer": str(self.first.pk), "workspace": str(self.foreign_ws.id)},
        ):
            self.assertEqual(
                self.client.patch(self.renewal(), payload, format="json").status_code,
                400, payload,
            )
        self.assertEqual(self.client.delete(self.item()).status_code, 204)
        self.assertEqual(self.client.patch(self.renewal(), {
            "insurer": str(self.first.pk),
        }, format="json").status_code, 400)
        self.assertEqual(self.client.patch(
            self.renewal(), {"insurer": None}, format="json",
        ).status_code, 200)

    def test_member_cannot_edit_catalog_or_see_foreign(self):
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.post(
            self.listing(), {"name": "Nueva Seguros"}, format="json",
        ).status_code, 403)
        self.assertEqual(self.client.patch(
            self.item(), {"name": "Otro nombre"}, format="json",
        ).status_code, 403)
        self.assertEqual(self.client.delete(self.item()).status_code, 403)
        self.assertEqual(self.client.get(self.item(self.second, self.foreign_ws)).status_code, 405)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.listing()).status_code, (401, 403))

    def test_filters_apply_before_daily_and_monthly_aggregation(self):
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.patch(self.renewal(), {
            "insurer": str(self.first.pk),
        }, format="json").status_code, 400)  # member cannot create cross-role? Change from owner below.
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.patch(self.renewal(), {
            "insurer": str(self.first.pk),
        }, format="json").status_code, 200)
        self.client.force_authenticate(user=self.member)
        sid = str(self.first.pk)
        api_list = reverse("api-renewals", kwargs={"workspace_id": self.ws.pk})
        api_day = reverse("api-agenda-day", kwargs={"workspace_id": self.ws.pk})
        api_month = reverse("api-agenda-month", kwargs={"workspace_id": self.ws.pk})
        result = self.client.get(api_list + "?insurer=" + sid)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data["count"], 1)
        result = self.client.get(api_day + "?day=2027-04-29&insurer=" + sid)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data["count"], 1)
        result = self.client.get(api_month + "?month=2027-04&insurer=" + sid)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data["days"][0]["expiry"]["pending"], 1)
        self.assertNotIn("POLIZA-FICTICIA", str(result.data))
        self.assertEqual(self.client.get(api_list + "?insurer=otro").status_code, 400)
        self.assertEqual(self.client.get(api_list + "?insurer=" + sid + "&insurer=" + sid).status_code, 400)

    def test_historial_solo_campo_y_no_nombre(self):
        self.client.force_authenticate(user=self.owner)
        result = self.client.patch(self.renewal(), {
            "insurer": str(self.first.pk),
        }, format="json")
        self.assertEqual(result.status_code, 200)
        event = RenewalAuditEvent.objects.filter(renewal=self.legacy).last()
        self.assertIsNotNone(event)
        self.assertIn("insurer_id", event.changed_fields)
        self.assertNotIn("Aseguradora Prueba A", str(event.metadata))
