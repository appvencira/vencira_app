"""Aislamiento y límites de sugerencias de datos entre anotaciones."""
from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from .models import Renewal, Workspace, WorkspaceMember


class PersonSuggestionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_user(username="sugg_owner")
        cls.member = get_user_model().objects.create_user(username="sugg_member")
        cls.other_user = get_user_model().objects.create_user(username="sugg_other")
        cls.workspace = Workspace.objects.create(name="Cuenta A")
        cls.other_workspace = Workspace.objects.create(name="Cuenta B")
        WorkspaceMember.objects.create(workspace=cls.workspace, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(workspace=cls.workspace, user=cls.member, role="member")
        WorkspaceMember.objects.create(workspace=cls.other_workspace, user=cls.other_user, role="owner")
        cls.mine = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.member,
            customer_reference="DEMO-A", full_name="Persona Ejemplo",
            nickname="Alias prueba", phone="600111222", email="ejemplo@example.invalid",
            expires_on=date(2027, 5, 1),
        )
        Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.owner,
            customer_reference="DEMO-OWNER", full_name="Persona Reservada",
            phone="600111222", expires_on=date(2027, 5, 1),
        )
        Renewal.objects.create(
            workspace=cls.other_workspace, assigned_to=cls.other_user,
            customer_reference="DEMO-B", full_name="Persona Otra Cuenta",
            phone="600111222", expires_on=date(2027, 5, 1),
        )

    def _url(self, workspace=None):
        return reverse("api-person-suggestions", kwargs={
            "workspace_id": workspace or self.workspace.pk,
        })

    def test_anonymous_denied(self):
        self.assertIn(self.client.get(self._url(), {"q": "Pers"}).status_code, (401, 403))

    def test_member_sees_only_assigned_annotations(self):
        self.client.force_login(self.member)
        response = self.client.get(self._url(), {"q": "Pers"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(response.json()[0]["source_id"], str(self.mine.pk))
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertNotIn("customer_reference", response.json()[0])

    def test_cross_workspace_returns_404(self):
        self.client.force_login(self.member)
        self.assertEqual(
            self.client.get(self._url(self.other_workspace.pk), {"q": "Pers"}).status_code,
            404,
        )

    def test_owner_sees_only_own_workspace(self):
        self.client.force_login(self.owner)
        response = self.client.get(self._url(), {"q": "Pers"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 2)

    def test_phone_lookup_and_self_exclusion(self):
        self.client.force_login(self.member)
        response = self.client.get(self._url(), {"by": "phone", "q": "600111222"})
        self.assertEqual(len(response.json()), 1)
        response = self.client.get(self._url(), {
            "by": "phone", "q": "600111222", "exclude": str(self.mine.pk),
        })
        self.assertEqual(response.json(), [])

    def test_short_invalid_and_duplicate_queries(self):
        self.client.force_login(self.member)
        for query in ("Pe", "", "x" * 161):
            self.assertEqual(self.client.get(self._url(), {"q": query}).status_code, 400)
        self.assertEqual(self.client.get(self._url() + "?q=Pers&q=Persona").status_code, 400)
        self.assertEqual(self.client.get(self._url(), {"q": "Pers", "unexpected": "1"}).status_code, 400)

    def test_converted_prospect_suggests_clients_only_to_authorized_source(self):
        self.mine.entry = Renewal.Entry.CLIENTS
        self.mine.archive_outcome = "won"
        self.mine.save(update_fields=["entry", "archive_outcome"])
        self.client.force_login(self.member)
        response = self.client.get(self._url(), {"q": "Persona Eje"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()[0]["suggested_entry"], "clients")
        self.assertNotIn("customer_reference", response.json()[0])
        self.client.force_login(self.other_user)
        self.assertEqual(self.client.get(self._url(), {"q": "Persona Eje"}).status_code, 404)
        self.client.force_login(self.owner)
        response = self.client.get(self._url(), {"q": "Persona Eje"})
        self.assertEqual(response.json()[0]["suggested_entry"], "clients")

    def test_unconverted_person_never_auto_reclassified(self):
        self.client.force_login(self.member)
        response = self.client.get(self._url(), {"q": "Persona Eje"})
        self.assertEqual(response.status_code, 200)
        self.assertIsNone(response.json()[0]["suggested_entry"])
