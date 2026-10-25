"""Explicit activation requires saved draft, current revision and authorization."""
import json
from unittest.mock import patch
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

    def test_repeated_activation_is_idempotent(self):
        RenewalReminderDraft.objects.create(
            renewal=self.renewal, days_before=[60, 45, 35], revision=1)
        self.client.force_login(self.owner)
        with patch("reminders.reminder_activate.timezone.localdate",
                   return_value=date(2027, 1, 1)):
            first = self.post(1)
            second = self.post(1)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["planned_count"], 3)
        self.assertEqual(second.json()["planned_count"], 3)
        self.assertEqual(OperationalReminder.objects.count(), 3)
        self.assertEqual(first.json()["notification_delivery"], "not_implemented")

    def test_configured_reason_is_used_by_activation(self):
        RenewalReminderDraft.objects.create(
            renewal=self.renewal, days_before=[60, 45, 35],
            reasons_by_day={"45": "Revisar propuesta"}, revision=1)
        self.client.force_login(self.owner)
        with patch("reminders.reminder_activate.timezone.localdate",
                   return_value=date(2027, 1, 1)):
            response = self.post(1)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(OperationalReminder.objects.get(
            renewal=self.renewal, source_key="expiry:45").reason, "Revisar propuesta")
        self.assertEqual(OperationalReminder.objects.get(
            renewal=self.renewal, source_key="expiry:60").reason, "Aviso de vencimiento")
