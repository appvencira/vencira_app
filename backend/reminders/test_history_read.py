"""Whitepaper §11: historial privado de anotación, lectura exclusivamente."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import Renewal, RenewalAuditEvent, Workspace, WorkspaceMember
from .audit import make_audit_event


class HistoryReadTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model()
        cls.owner = users.objects.create_user(username="hist-owner", password="local-only-Owner!1")
        cls.alice = users.objects.create_user(username="hist-alice", password="local-only-Alice!1")
        cls.bob = users.objects.create_user(username="hist-bob", password="local-only-Bob!1")
        cls.foreign = users.objects.create_user(username="hist-foreign", password="local-only-Foreign!1")
        cls.a = Workspace.objects.create(name="HISTORIAL-A")
        cls.b = Workspace.objects.create(name="HISTORIAL-B")
        for user, role in (
            (cls.owner, WorkspaceMember.Role.OWNER),
            (cls.alice, WorkspaceMember.Role.MEMBER),
            (cls.bob, WorkspaceMember.Role.MEMBER),
        ):
            WorkspaceMember.objects.create(user=user, workspace=cls.a, role=role)
        WorkspaceMember.objects.create(user=cls.foreign, workspace=cls.b, role=WorkspaceMember.Role.OWNER)
        cls.renewal = Renewal.objects.create(
            workspace=cls.a, assigned_to=cls.alice,
            customer_reference="PERSONA-PRIVADA-PRUEBA", expires_on=date(2027, 4, 30),
        )
        make_audit_event(renewal=cls.renewal, actor=cls.alice)
        cls.renewal.expires_on = date(2027, 5, 30)
        cls.renewal.save(update_fields=["expires_on"])
        from .models import RenewalAuditEvent
        RenewalAuditEvent.objects.create(
            workspace=cls.a, renewal=cls.renewal, actor=cls.alice,
            action=RenewalAuditEvent.Action.UPDATED,
            changed_fields=["expires_on"],
            metadata={"expires_on": {"before": "2027-04-30", "after": "2027-05-30"}},
        )
        cls.other_item = Renewal.objects.create(
            workspace=cls.b, assigned_to=cls.foreign,
            customer_reference="EXTRANJERO", expires_on=date(2027, 6, 1),
        )

    def path(self, workspace=None, renewal=None):
        return reverse("api-renewal-history", kwargs={
            "workspace_id": (workspace or self.a).id,
            "renewal_id": (renewal or self.renewal).id,
        })

    def test_member_own_read_only_history_paged_and_no_personal_reference(self):
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.path() + "?page_size=1")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(response.data["count"], 2)
        self.assertEqual(len(response.data["results"]), 1)
        event = response.data["results"][0]
        self.assertEqual(event["action"], "updated")
        self.assertEqual(event["actor"], "hist-alice")
        self.assertEqual(event["changed_fields"], ["expires_on"])
        self.assertEqual(event["metadata"]["expires_on"]["after"], "2027-05-30")
        self.assertNotIn("PERSONA-PRIVADA-PRUEBA", str(response.data))
        self.assertEqual(self.client.post(self.path(), {"action": "deleted"}, format="json").status_code, 405)
        self.assertEqual(self.client.patch(self.path(), {"action": "deleted"}, format="json").status_code, 405)
        self.assertEqual(self.client.delete(self.path()).status_code, 405)
        self.assertEqual(RenewalAuditEvent.objects.count(), 2)

    def test_owner_can_see_team_and_member_cannot_see_others(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.path()).status_code, 200)
        self.client.force_authenticate(user=self.bob)
        self.assertEqual(self.client.get(self.path()).status_code, 404)
        self.client.force_authenticate(user=self.foreign)
        self.assertEqual(self.client.get(self.path()).status_code, 404)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.path()).status_code, (401, 403))

    def test_foreign_workspace_is_not_exposed_even_to_owner(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.path(workspace=self.b, renewal=self.other_item)).status_code, 404)
        self.assertEqual(self.client.get(self.path(renewal=self.other_item)).status_code, 404)

    def test_preexisting_legacy_without_history_has_empty_response(self):
        legacy = Renewal.objects.create(
            workspace=self.a, assigned_to=self.alice,
            customer_reference="SIN-AUDITORIA", expires_on=date(2027, 7, 1),
        )
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.path(renewal=legacy))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 0)
        self.assertEqual(response.data["results"], [])
