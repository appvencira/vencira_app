"""Whitepaper §2/§6: Entrada Clientes/Candidatos y modalidad, sin datos reales."""
from datetime import date
from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase
from .models import Renewal, RenewalAuditEvent, Workspace, WorkspaceMember


class EntryModalityTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        U = get_user_model()
        cls.owner = U.objects.create_user(username="entry-owner", password="demo-not-real-1!")
        cls.member = U.objects.create_user(username="entry-member", password="demo-not-real-2!")
        cls.other = U.objects.create_user(username="entry-other", password="demo-not-real-3!")
        cls.ws = Workspace.objects.create(name="Entradas / entidad ficticia")
        cls.foreign = Workspace.objects.create(name="Organización ajena ficticia")
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.owner, role=WorkspaceMember.Role.OWNER)
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.member, role=WorkspaceMember.Role.MEMBER)
        WorkspaceMember.objects.create(
            workspace=cls.foreign, user=cls.other, role=WorkspaceMember.Role.OWNER)
        cls.legacy = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="LEGACY-DEMO", expires_on=date(2027, 3, 31))
        cls.other_item = Renewal.objects.create(
            workspace=cls.foreign, assigned_to=cls.other,
            customer_reference="AJENO-DEMO", expires_on=date(2027, 4, 30))

    def url(self, ws=None):
        return reverse("api-renewals", kwargs={"workspace_id": (ws or self.ws).pk})

    def detail(self, item, ws=None):
        return reverse("api-renewal-detail", kwargs={
            "workspace_id": (ws or self.ws).pk, "renewal_id": item.pk})

    def test_legacy_unchanged_and_unclassified(self):
        self.client.force_authenticate(user=self.member)
        res = self.client.get(self.detail(self.legacy))
        self.assertEqual(res.status_code, 200)
        self.assertIsNone(res.data["entry"])
        self.assertEqual(res.data["modality"], "")
        self.assertEqual(Renewal.objects.get(pk=self.legacy.pk).entry, None)

    def test_new_prospect_and_patch_client_are_audited_without_private_values(self):
        self.client.force_authenticate(user=self.member)
        res = self.client.post(self.url(), {
            "customer_reference": "DEMO-CANDIDATO-1",
            "full_name": "Candidato ficticio",
            "expires_on": "2027-05-01", "entry": "prospects",
            "modality": "autos", "status": "pending",
        }, format="json")
        self.assertEqual(res.status_code, 201, res.data)
        self.assertEqual(res.data["entry"], "prospects")
        self.assertEqual(res.data["modality"], "autos")
        item = Renewal.objects.get(pk=res.data["id"])
        self.assertEqual(item.assigned_to_id, self.member.id)
        patch = self.client.patch(self.detail(item), {
            "entry": "clients", "modality": "salud",
        }, format="json")
        self.assertEqual(patch.status_code, 200)
        self.assertEqual(patch.data["entry"], "clients")
        self.assertEqual(patch.data["modality"], "salud")
        records = RenewalAuditEvent.objects.filter(renewal=item).order_by("created_at")
        self.assertEqual(records.count(), 2)
        self.assertEqual(records.last().changed_fields, ["entry", "modality"])
        self.assertNotIn("DEMO-CANDIDATO-1", str(records.last().metadata))
        self.assertNotIn("salud", str(records.last().metadata))

    def test_unknown_entry_and_mass_assignment_fail(self):
        self.client.force_authenticate(user=self.owner)
        for payload in (
            {"entry": "otro"}, {"entry": ""}, {"entry": None},
            {"entry": "clients", "workspace": str(self.foreign.id)},
        ):
            with self.subTest(payload=payload):
                res = self.client.patch(self.detail(self.legacy), payload, format="json")
                self.assertEqual(res.status_code, 400, res.data)
        self.assertFalse(RenewalAuditEvent.objects.filter(renewal=self.legacy).exists())

    def test_owner_and_member_scope_unchanged(self):
        self.client.force_authenticate(user=self.member)
        r = self.client.get(self.detail(self.other_item, ws=self.foreign))
        self.assertEqual(r.status_code, 404)
        r = self.client.get(self.detail(self.other_item, ws=self.ws))
        self.assertEqual(r.status_code, 404)
        self.client.force_authenticate(user=self.other)
        self.assertEqual(self.client.get(self.detail(self.legacy, ws=self.foreign)).status_code, 404)

    def test_patch_legacy_can_reclassify_without_changing_dates(self):
        self.client.force_authenticate(user=self.member)
        res = self.client.patch(self.detail(self.legacy), {
            "entry": "clients", "modality": "hogar",
        }, format="json")
        self.assertEqual(res.status_code, 200)
        self.legacy.refresh_from_db()
        self.assertEqual(self.legacy.expires_on, date(2027, 3, 31))
        self.assertEqual(self.legacy.entry, "clients")
        self.assertEqual(self.legacy.modality, "hogar")

    def test_whitepaper_three_fields_required_and_opaque_reference_optional(self):
        self.client.force_authenticate(user=self.owner)
        base = {
            "entry": "clients", "full_name": "Entidad ficticia",
            "expires_on": "2027-05-01",
        }
        for missing in ("entry", "full_name", "expires_on"):
            data = dict(base)
            data.pop(missing)
            response = self.client.post(self.url(), data, format="json")
            self.assertEqual(response.status_code, 400, response.data)
            self.assertIn(missing, response.data)
        response = self.client.post(self.url(), base, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data["full_name"], "Entidad ficticia")
        self.assertEqual(response.data["entry"], "clients")
        self.assertTrue(response.data["customer_reference"].startswith("V-"))
        self.assertEqual(len(response.data["customer_reference"]), 34)
        self.assertEqual(RenewalAuditEvent.objects.filter(
            renewal_id=response.data["id"]).count(), 1)
        self.assertNotIn("Entidad ficticia", str(RenewalAuditEvent.objects.get(
            renewal_id=response.data["id"]).metadata))
