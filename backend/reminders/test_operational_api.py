"""Multi-tenant and ownership visibility for internal reminder reads."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from reminders.models import Workspace, WorkspaceMember, Renewal, OperationalReminder

class OperationalApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="own_a", password="test-str0ng-a!")
        self.other = User.objects.create_user(username="own_b", password="test-str0ng-b!")
        self.ws = Workspace.objects.create(name="A")
        self.ws_other = Workspace.objects.create(name="B")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.owner, role="owner")
        WorkspaceMember.objects.create(workspace=self.ws_other, user=self.other, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="FICTICIO", expires_on=date(2027, 3, 15))
        OperationalReminder.objects.create(
            renewal=self.renewal, kind="expiry", source_key="expiry:35",
            scheduled_for=date(2027, 2, 8),
            original_scheduled_for=date(2027, 2, 8),
            reason="Aviso ficticio", days_before=35)
        self.url = reverse("api-operational-reminders",
            kwargs={"workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})

    def test_authorized_owner_reads_only_internal_occurrences(self):
        self.client.force_login(self.owner)
        result = self.client.get(self.url)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(len(result.json()["results"]), 1)
        self.assertEqual(result.json()["results"][0]["delivery_status"], "not_implemented")
        self.assertEqual(result["Cache-Control"], "no-store")

    def test_unrelated_user_cannot_read_or_write(self):
        self.client.force_login(self.other)
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(self.client.post(self.url, data={}).status_code, 405)

    def test_method_and_query_rejected(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.client.post(self.url, data={}).status_code, 405)
        self.assertEqual(self.client.get(self.url + "?unsafe=1").status_code, 400)
