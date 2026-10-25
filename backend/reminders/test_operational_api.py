"""Multi-tenant and ownership visibility for internal reminder reads."""
from datetime import date
import json
import uuid
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
        self.reminder = OperationalReminder.objects.create(
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

    def action(self, user, *, key=None, state="planned", day="2027-02-08",
               action="complete", days=None):
        self.client.force_login(user)
        url = reverse("api-operational-reminder-action", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "reminder_id": self.reminder.pk})
        return self.client.post(url, data=json.dumps({
            "action": action, "expected_state": state, "expected_day": day,
            "idempotency_key": str(key or uuid.uuid4()), "days_later": days,
        }), content_type="application/json")

    def test_action_succeeds_and_replay_is_idempotent(self):
        key = uuid.uuid4()
        first = self.action(self.owner, key=key)
        second = self.action(self.owner, key=key)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["state"], "completed")
        self.assertEqual(first.json()["delivery_status"], "not_implemented")

    def test_action_stale_conflict(self):
        self.assertEqual(self.action(self.owner).status_code, 200)
        self.assertEqual(self.action(self.owner).status_code, 409)

    def test_action_other_workspace_is_not_visible(self):
        self.assertEqual(self.action(self.other).status_code, 404)

    def test_action_rejects_bad_json_contract(self):
        self.client.force_login(self.owner)
        url = reverse("api-operational-reminder-action", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "reminder_id": self.reminder.pk})
        self.assertEqual(self.client.post(
            url, data=json.dumps({"action": "complete"}),
            content_type="application/json").status_code, 400)
