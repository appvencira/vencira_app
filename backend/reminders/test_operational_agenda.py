"""Regression: operational reminder appears in daily and monthly agenda."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from reminders.models import Workspace, WorkspaceMember, Renewal, OperationalReminder


class OperationalAgendaTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="agenda_op", password="test-agenda-2026!")
        self.ws = Workspace.objects.create(name="Agenda demo")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.user, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.user,
            customer_reference="FICTICIO", expires_on=date(2027, 3, 15),
            status="pending")
        self.client.force_login(self.user)

    def test_operational_only_occurrence_in_day_and_month(self):
        OperationalReminder.objects.create(
            renewal=self.renewal, kind="control_repeat",
            scheduled_for=date(2027, 2, 10),
            original_scheduled_for=date(2027, 2, 10),
            source_key="control:test", reason="Control interno",
            control_question=True)
        daily = self.client.get(reverse("api-agenda-day", kwargs={
            "workspace_id": self.ws.pk}), {"day": "2027-02-10"})
        self.assertEqual(daily.status_code, 200)
        self.assertIn("operational_reminder",
            [v["kind"] for v in daily.json()["results"][0]["events"]])
        month = self.client.get(reverse("api-agenda-month", kwargs={
            "workspace_id": self.ws.pk}), {"month": "2027-02"})
        self.assertEqual(month.status_code, 200)
        record = next(x for x in month.json()["days"] if x["day"] == "2027-02-10")
        self.assertEqual(record["reminder"]["pending"], 1)

    def test_completed_does_not_appear_as_future_pending(self):
        OperationalReminder.objects.create(
            renewal=self.renewal, kind="expiry",
            scheduled_for=date(2027, 2, 10),
            original_scheduled_for=date(2027, 2, 10),
            source_key="expiry:33", reason="Atendido", state="completed")
        daily = self.client.get(reverse("api-agenda-day", kwargs={
            "workspace_id": self.ws.pk}), {"day": "2027-02-10"})
        self.assertEqual(daily.status_code, 200)
        self.assertEqual(daily.json()["results"], [])
