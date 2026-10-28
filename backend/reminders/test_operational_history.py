"""Macrofase B: historia interna del aviso, sin efectos de lectura ni fugas."""
import uuid
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from reminders.models import (
    OperationalReminder, OperationalReminderEvent,
    Renewal, Workspace, WorkspaceMember,
)


class OperationalHistoryTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(
            username="history_owner", password="test")
        self.member = User.objects.create_user(
            username="history_member", password="test")
        self.other = User.objects.create_user(
            username="history_other", password="test")
        self.ws = Workspace.objects.create(name="Demo History")
        self.foreign = Workspace.objects.create(name="Other History")
        WorkspaceMember.objects.create(
            workspace=self.ws, user=self.owner, role="owner")
        WorkspaceMember.objects.create(
            workspace=self.ws, user=self.member, role="member")
        WorkspaceMember.objects.create(
            workspace=self.foreign, user=self.other, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.member,
            customer_reference="DEMO-H", expires_on=date(2027, 9, 1))
        self.owner_renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="DEMO-O", expires_on=date(2027, 9, 2))
        self.other_renewal = Renewal.objects.create(
            workspace=self.foreign, assigned_to=self.other,
            customer_reference="SECRET", expires_on=date(2027, 9, 3))
        self.reminder = self._reminder(self.renewal)
        self.other_reminder = self._reminder(self.other_renewal)
        self.owner_reminder = self._reminder(self.owner_renewal)
        self.url = self._url(self.ws, self.renewal, self.reminder)
        self.foreign_url = self._url(
            self.foreign, self.other_renewal, self.other_reminder)
        self.owner_url = self._url(
            self.ws, self.owner_renewal, self.owner_reminder)

    def _reminder(self, renewal):
        return OperationalReminder.objects.create(
            renewal=renewal, kind="expiry", state="planned",
            source_key="expiry:35", generation=1,
            scheduled_for=date(2027, 7, 28),
            original_scheduled_for=date(2027, 7, 28),
            reason="DEMO")

    def _url(self, ws, renewal, reminder):
        return reverse("api-operational-reminder-history", kwargs={
            "workspace_id": ws.pk, "renewal_id": renewal.pk,
            "reminder_id": reminder.pk})

    def _event(self, reminder, actor, action, old, new):
        return OperationalReminderEvent.objects.create(
            reminder=reminder, actor=actor, action=action,
            previous_state=old, next_state=new,
            scheduled_for=date(2027, 7, 29),
            idempotency_key=uuid.uuid4())

    def test_paginated_ordered_metadata_without_mutation_or_delivery(self):
        first = self._event(
            self.reminder, self.member, "planned", "", "planned")
        second = self._event(
            self.reminder, self.owner, "tomorrow", "planned", "snoozed")
        self._event(self.other_reminder, self.other,
                    "complete", "planned", "completed")
        self.client.force_login(self.owner)
        before = OperationalReminderEvent.objects.count()
        response = self.client.get(self.url, {"page_size": "1", "page": "1"})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["count"], 2)
        self.assertEqual(data["delivery_status"], "not_implemented")
        self.assertEqual(data["results"][0]["id"], str(second.pk))
        self.assertEqual(data["results"][0]["actor"], "history_owner")
        self.assertEqual(data["results"][0]["action"], "tomorrow")
        self.assertEqual(data["results"][0]["previous_state"], "planned")
        self.assertEqual(data["results"][0]["next_state"], "snoozed")
        self.assertEqual(data["results"][0]["scheduled_for"], "2027-07-29")
        self.assertTrue(data["results"][0]["occurred_at"])
        self.assertNotIn("idempotency_key", data["results"][0])
        self.assertNotIn("renewal_id", data["results"][0])
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertIsNotNone(data["next"])
        self.assertEqual(self.client.get(self.url, {
            "page_size": "1", "page": "2"
        }).json()["results"][0]["id"], str(first.pk))
        self.assertEqual(OperationalReminderEvent.objects.count(), before)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.state, "planned")

    def test_workspace_and_assignment_security(self):
        self._event(self.reminder, self.member, "planned", "", "planned")
        self._event(self.owner_reminder, self.owner, "planned", "", "planned")
        self.client.force_login(self.member)
        self.assertEqual(self.client.get(self.url).status_code, 200)
        self.assertEqual(self.client.get(self.owner_url).status_code, 404)
        self.assertEqual(self.client.get(self.foreign_url).status_code, 404)
        self.client.force_login(self.other)
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(self.client.get(self.foreign_url).status_code, 200)

    def test_removed_actor_not_disclosed_but_event_kept(self):
        self._event(self.reminder, self.owner, "complete", "planned", "completed")
        WorkspaceMember.objects.filter(
            workspace=self.ws, user=self.owner).delete()
        self.client.force_login(self.member)
        data = self.client.get(self.url).json()
        self.assertEqual(data["results"][0]["actor"], None)
        self.assertEqual(data["results"][0]["action"], "complete")

    def test_completed_and_cancelled_events_are_still_accessible(self):
        self._event(self.reminder, self.owner,
                    "cancelled", "planned", "cancelled")
        self.reminder.state = "cancelled"
        self.reminder.save(update_fields=["state"])
        self.client.force_login(self.owner)
        self.assertEqual(self.client.get(self.url).json()["count"], 1)

    def test_rejects_unknown_queries_and_writes(self):
        self.client.force_login(self.owner)
        for parameters in (
            {"page": "-1"}, {"page": "0"},
            {"page_size": "0"}, {"page": "1.1"},
            {"junk": "x"}, {"page_size": "100001"},
        ):
            self.assertEqual(
                self.client.get(self.url, parameters).status_code,
                400, parameters)
        self.assertEqual(
            self.client.get(self.url + "?page=1&page=2").status_code, 400)
        self.assertEqual(self.client.post(self.url, {}).status_code, 405)

    def test_anonymous_and_mismatched_reminder(self):
        self.assertIn(self.client.get(self.url).status_code, (401, 403))
        self.client.force_login(self.owner)
        path = self._url(self.ws, self.renewal, self.other_reminder)
        self.assertEqual(self.client.get(path).status_code, 404)
        self.assertEqual(self.client.get(self.url).json()["count"], 0)
