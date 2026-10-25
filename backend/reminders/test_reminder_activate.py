"""Explicit activation requires saved draft, current revision and authorization."""
import json
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from reminders.models import Workspace, WorkspaceMember, Renewal, RenewalReminderDraft, OperationalReminder


class ReminderActivationTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="act_owner", password="test-owner-abc!")
        self.other = User.objects.create_user(username="act_other", password="test-other-abc!")
        self.ws = Workspace.objects.create(name="Act")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.owner, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner, customer_reference="TEST",
            expires_on=date(2027, 3, 15), modality="autos")
        self.url = reverse("api-reminder-activate", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})

    def post(self, expected):
        return self.client.post(
            self.url, json.dumps({"expected_revision": expected}),
            content_type="application/json")

    def test_draft_required(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.post(1).status_code, 404)

    def test_cross_tenant_denied(self):
        self.client.force_login(self.other)
        self.assertEqual(self.post(1).status_code, 404)

    def test_revision_conflict(self):
        RenewalReminderDraft.objects.create(
            renewal=self.renewal, days_before=[60, 45, 35], revision=2)
        self.client.force_login(self.owner)
        self.assertEqual(self.post(1).status_code, 409)
        self.assertFalse(OperationalReminder.objects.exists())

    def test_invalid_payload_is_rejected(self):
        self.client.force_login(self.owner)
        response = self.client.post(
            self.url, json.dumps({"expected_revision": True}),
            content_type="application/json")
        self.assertEqual(response.status_code, 400)
        self.assertFalse(OperationalReminder.objects.exists())
