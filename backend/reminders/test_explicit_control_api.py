"""Explicit controls: tenant scope, confirmation, dates, audit and retries."""
import uuid
from datetime import date
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from .models import (Renewal, Workspace, WorkspaceMember, RenewalReminderDraft,
                     OperationalReminder, OperationalReminderEvent)


class ExplicitControlApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_user(username="explicit-owner")
        cls.other = get_user_model().objects.create_user(username="explicit-other")
        cls.ws = Workspace.objects.create(name="C2 control synthetic")
        cls.foreign = Workspace.objects.create(name="C2 foreign synthetic")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(workspace=cls.foreign, user=cls.other, role="owner")
        cls.renewal = Renewal.objects.create(
            workspace=cls.ws, customer_reference="C2-SYNTHETIC",
            expires_on=date(2027, 3, 15))
        RenewalReminderDraft.objects.create(
            renewal=cls.renewal, days_before=[20, 15],
            state="draft", created_by=cls.owner, updated_by=cls.owner)

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def url(self):
        return reverse("api-explicit-control", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})

    def data(self, day="2027-02-14", **kwargs):
        result = {"confirmed": True, "scheduled_for": day,
                  "idempotency_key": str(uuid.uuid4())}
        result.update(kwargs)
        return result

    @patch("reminders.explicit_control_api.timezone.localdate",
           return_value=date(2027, 2, 1))
    def test_requires_confirmation_and_no_duplicate(self, _):
        payload = self.data()
        self.assertEqual(self.client.post(self.url(), {
            **payload, "confirmed": False}, format="json").status_code, 400)
        self.assertEqual(OperationalReminder.objects.count(), 0)
        first = self.client.post(self.url(), payload, format="json")
        self.assertEqual(first.status_code, 201, first.data)
        self.assertEqual(first.data["delivery_status"], "not_implemented")
        replay = self.client.post(self.url(), payload, format="json")
        self.assertEqual(replay.status_code, 200)
        self.assertEqual(replay.data["id"], first.data["id"])
        self.assertEqual(OperationalReminder.objects.count(), 1)
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)
        self.assertEqual(OperationalReminderEvent.objects.get().actor, self.owner)
        conflict = self.client.post(self.url(), {
            **payload, "scheduled_for": "2027-02-13"}, format="json")
        self.assertEqual(conflict.status_code, 409)

    @patch("reminders.explicit_control_api.timezone.localdate",
           return_value=date(2027, 2, 1))
    def test_cutoff_and_duplicate_day_blocked(self, _):
        self.assertEqual(self.client.post(self.url(), self.data(
            "2027-02-15"), format="json").status_code, 400)
        self.assertEqual(self.client.post(self.url(), self.data(
            "2027-01-31"), format="json").status_code, 400)
        self.assertEqual(self.client.post(self.url(), self.data(
            "2027-02-14"), format="json").status_code, 201)
        self.assertEqual(self.client.post(self.url(), self.data(
            "2027-02-14"), format="json").status_code, 409)
        self.assertEqual(OperationalReminder.objects.count(), 1)

    @patch("reminders.explicit_control_api.timezone.localdate",
           return_value=date(2027, 2, 15))
    def test_at_cutoff_cannot_create(self, _):
        self.assertEqual(self.client.post(self.url(), self.data(),
            format="json").status_code, 409)
        self.assertFalse(OperationalReminder.objects.exists())

    @patch("reminders.explicit_control_api.timezone.localdate",
           return_value=date(2027, 2, 1))
    def test_scope_and_life_safety(self, _):
        self.client.force_authenticate(user=self.other)
        self.assertEqual(self.client.post(self.url(), self.data(),
            format="json").status_code, 404)
        self.client.force_authenticate(user=self.owner)
        self.renewal.modality = "vida"
        self.renewal.save(update_fields=["modality"])
        self.assertEqual(self.client.post(self.url(), self.data(),
            format="json").status_code, 409)
        self.assertFalse(OperationalReminder.objects.exists())
