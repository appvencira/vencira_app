"""Whitepaper §6: catálogo por cuenta, integridad y filtros seguros."""
from datetime import date
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from .models import Renewal, Workspace, WorkspaceMember, WorkspaceModality


class ModalityCatalogTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        U = get_user_model()
        cls.owner = U.objects.create_user(username="cat-owner")
        cls.member = U.objects.create_user(username="cat-member")
        cls.foreign = U.objects.create_user(username="cat-foreign")
        cls.ws = Workspace.objects.create(name="Cuenta ficticia catálogo")
        cls.other = Workspace.objects.create(name="Cuenta ajena")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.member, role="member")
        WorkspaceMember.objects.create(workspace=cls.other, user=cls.foreign, role="owner")
        cls.one = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="TEST-CLIENTE", expires_on=date(2027, 4, 25),
            entry="clients", modality="hogar",
        )
        cls.two = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="TEST-CANDIDATO", expires_on=date(2027, 4, 25),
            notice_deadline_on=date(2027, 4, 23),
            entry="prospects", modality="autos",
        )
        cls.third = Renewal.objects.create(
            workspace=cls.other, assigned_to=cls.foreign,
            customer_reference="TEST-AJENO", expires_on=date(2027, 4, 25),
            entry="clients", modality="hogar",
        )

    def list_url(self, workspace=None):
        return reverse("api-modalities", kwargs={"workspace_id": (workspace or self.ws).pk})

    def detail_url(self, code, workspace=None):
        return reverse("api-modality-detail", kwargs={
            "workspace_id": (workspace or self.ws).pk, "code": code,
        })

    def test_defaults_without_rows_and_private_tenant_catalog(self):
        self.client.force_authenticate(user=self.member)
        res = self.client.get(self.list_url())
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res["Cache-Control"], "no-store")
        self.assertEqual(len(res.data), 12)
        self.assertEqual(WorkspaceModality.objects.count(), 0)
        self.assertIn("hogar", [row["code"] for row in res.data])
        self.assertEqual(self.client.get(self.list_url(self.other)).status_code, 404)

    def test_member_cannot_mutate_even_with_valid_json(self):
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.post(self.list_url(), {"label": "Mascotas"}).status_code, 403)
        self.assertEqual(self.client.patch(self.detail_url("hogar"), {"label": "Casa"}).status_code, 403)
        self.assertEqual(self.client.delete(self.detail_url("hogar")).status_code, 403)

    def test_add_rename_disable_reactivate_and_preserve_renewals(self):
        self.client.force_authenticate(user=self.owner)
        created = self.client.post(self.list_url(), {"label": "Mascotas"}, format="json")
        self.assertEqual(created.status_code, 201, created.data)
        code = created.data["code"]
        self.assertTrue(code.startswith("custom-"))
        self.assertEqual(self.client.post(self.list_url(), {"label": "mAsCoTaS"}).status_code, 409)
        self.assertEqual(self.client.patch(
            self.detail_url(code), {"label": "Animales domésticos"}, format="json"
        ).status_code, 200)
        # Renombrado de opción predeterminada sin cambiar su código.
        self.assertEqual(self.client.patch(
            self.detail_url("hogar"), {"label": "Vivienda"}, format="json"
        ).status_code, 200)
        self.assertEqual(self.one.modality, "hogar")
        self.assertEqual(self.client.delete(self.detail_url("hogar")).status_code, 204)
        options = {row["code"]: row for row in self.client.get(self.list_url()).data}
        self.assertFalse(options["hogar"]["active"])
        self.assertEqual(options["hogar"]["label"], "Vivienda")
        self.one.refresh_from_db()
        self.assertEqual(self.one.modality, "hogar")
        # No reutilizar código borrado para crear otra modalidad.
        self.assertEqual(self.client.post(self.list_url(), {"label": "Vivienda"}).status_code, 201)
        self.assertEqual(self.client.patch(
            self.detail_url("hogar"), {"active": True}, format="json"
        ).status_code, 409)  # choca con nombre recién creado
        self.assertEqual(self.client.delete(self.detail_url(code)).status_code, 204)
        self.assertEqual(self.client.patch(
            self.detail_url(code), {"label": "Animales", "active": True}, format="json"
        ).status_code, 200)

    def test_renames_only_current_workspace(self):
        self.client.force_authenticate(user=self.owner)
        self.client.patch(self.detail_url("autos"), {"label": "Coches"}, format="json")
        self.client.force_authenticate(user=self.foreign)
        options = {row["code"]: row for row in self.client.get(self.list_url(self.other)).data}
        self.assertEqual(options["autos"]["label"], "Autos")
        self.assertEqual(self.client.patch(self.detail_url("hogar"), {"label": "Prueba"}).status_code, 404)

    def test_invalid_payload_and_inactive_modality_rejected_for_new(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.post(self.list_url(), {"label": "   "}).status_code, 400)
        self.assertEqual(self.client.post(self.list_url(), {"label": "X", "workspace": str(self.other.id)}).status_code, 400)
        self.assertEqual(self.client.patch(self.detail_url("hogar"), {"active": False}).status_code, 400)
        self.assertEqual(self.client.delete(self.detail_url("hogar")).status_code, 204)
        base = reverse("api-renewals", kwargs={"workspace_id": self.ws.pk})
        payload = {"customer_reference": "DEMO", "expires_on": "2027-05-01",
                   "entry": "clients", "modality": "hogar"}
        self.assertEqual(self.client.post(base, payload, format="json").status_code, 400)
        # Un registro preexistente puede conservar la modalidad desactivada.
        detail = reverse("api-renewal-detail", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.one.pk
        })
        self.assertEqual(self.client.patch(detail, {"status": "contacted", "modality": "hogar"}, format="json").status_code, 200)
        self.assertEqual(self.client.patch(detail, {"modality": "otra-cuenta"}, format="json").status_code, 400)

    def test_entry_and_modality_filter_list_and_agenda(self):
        self.client.force_authenticate(user=self.member)
        base = reverse("api-renewals", kwargs={"workspace_id": self.ws.pk})
        day = reverse("api-agenda-day", kwargs={"workspace_id": self.ws.pk})
        month = reverse("api-agenda-month", kwargs={"workspace_id": self.ws.pk})
        for url in (base, day + "?day=2027-04-25&", month + "?month=2027-04&"):
            if "?" not in url:
                url += "?"
            elif not url.endswith("&"):
                url += "&"
            res = self.client.get(url + "entry=clients&modality=hogar")
            self.assertEqual(res.status_code, 200, res.data)
            if "agenda/month" in url:
                rows = {row["day"]: row for row in res.data["days"]}
                self.assertEqual(rows["2027-04-25"]["expiry"]["pending"], 1)
                self.assertNotIn("2027-04-23", rows)
            elif "agenda/" in url:
                self.assertEqual(res.data["count"], 1)
                self.assertEqual(res.data["results"][0]["renewal"]["customer_reference"], "TEST-CLIENTE")
            else:
                self.assertEqual(res.data["count"], 1)
                self.assertEqual(res.data["results"][0]["customer_reference"], "TEST-CLIENTE")
        for invalid in ("entry=other", "modality=%2e%2e", "entry=clients&entry=prospects"):
            self.assertEqual(self.client.get(base + "?" + invalid).status_code, 400)

    def test_no_session_cannot_read_or_edit(self):
        self.assertIn(self.client.get(self.list_url()).status_code, (401, 403))
        self.assertIn(self.client.post(self.list_url(), {"label": "Prueba"}).status_code, (401, 403))
