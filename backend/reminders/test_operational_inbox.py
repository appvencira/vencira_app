"""Macrofase B: read-only inbox, civil dates, visibility and pagination."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from reminders.models import (
    Workspace, WorkspaceMember, Renewal,
    OperationalReminder, OperationalReminderEvent,
)


class OperationalInboxTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="inbox_owner", password="secret1")
        self.member = User.objects.create_user(username="inbox_member", password="secret2")
        self.other = User.objects.create_user(username="inbox_other", password="secret3")
        self.ws = Workspace.objects.create(name="Inbox")
        self.foreign = Workspace.objects.create(name="Other")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.owner, role="owner")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.member, role="member")
        WorkspaceMember.objects.create(workspace=self.foreign, user=self.other, role="owner")
        self.mine = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.member,
            customer_reference="DEMO-A", expires_on=date(2027, 6, 1))
        self.owner_only = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="DEMO-B", expires_on=date(2027, 6, 2))
        self.foreign_renewal = Renewal.objects.create(
            workspace=self.foreign, assigned_to=self.other,
            customer_reference="SECRET-FOREIGN", expires_on=date(2027, 6, 3))
        self.url = reverse("api-operational-inbox", kwargs={
            "workspace_id": self.ws.id})
        self.foreign_url = reverse("api-operational-inbox", kwargs={
            "workspace_id": self.foreign.id})
        self.due = date(2027, 3, 10)

    def add(self, renewal, day, suffix, state="planned"):
        return OperationalReminder.objects.create(
            renewal=renewal, kind="expiry", state=state,
            source_key="expiry:" + suffix, generation=1,
            scheduled_for=day, original_scheduled_for=day,
            reason="DEMO-" + suffix)

    def test_counts_scope_order_and_no_side_effects(self):
        old = self.add(self.mine, date(2027, 3, 9), "old")
        today = self.add(self.mine, self.due, "today", state="snoozed")
        future = self.add(self.owner_only, date(2027, 3, 11), "future")
        self.add(self.mine, date(2027, 3, 8), "done", state="completed")
        self.add(self.owner_only, date(2027, 3, 8), "cancel", state="cancelled")
        self.add(self.foreign_renewal, date(2027, 3, 8), "foreign")
        self.client.force_login(self.owner)
        resp = self.client.get(self.url, {"day": "2027-03-10"})
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["counts"], {"overdue": 1, "today": 1, "upcoming": 1})
        self.assertEqual([r["id"] for r in data["results"]], [str(old.id), str(today.id)])
        self.assertEqual(data["results"][0]["overdue"], True)
        self.assertEqual(data["results"][1]["overdue"], False)
        self.assertEqual(data["results"][0]["delivery_status"], "not_implemented")
        self.assertEqual(resp["Cache-Control"], "no-store")
        self.assertEqual(OperationalReminderEvent.objects.count(), 0)
        self.assertEqual(OperationalReminder.objects.count(), 6)
        self.assertEqual(self.client.get(self.url, {"day": "2027-03-10",
            "scope": "overdue"}).json()["count"], 1)
        self.assertEqual(self.client.get(self.url, {"day": "2027-03-10",
            "scope": "today"}).json()["results"][0]["id"], str(today.id))
        self.assertEqual(self.client.get(self.url, {"day": "2027-03-10",
            "scope": "upcoming"}).json()["results"][0]["id"], str(future.id))

    def test_member_and_other_tenant_cannot_see_unassigned(self):
        self.add(self.mine, date(2027, 3, 9), "mine")
        self.add(self.owner_only, date(2027, 3, 9), "owner")
        self.add(self.foreign_renewal, date(2027, 3, 9), "foreign")
        self.client.force_login(self.member)
        data = self.client.get(self.url, {"day": "2027-03-10"}).json()
        self.assertEqual(data["counts"]["overdue"], 1)
        self.assertEqual([r["reference"] for r in data["results"]], ["DEMO-A"])
        self.assertEqual(self.client.get(self.foreign_url,
            {"day": "2027-03-10"}).status_code, 404)
        self.client.force_login(self.other)
        self.assertEqual(self.client.get(self.url, {"day": "2027-03-10"}).status_code, 404)

    def test_closed_archived_reminders_not_in_active_inbox(self):
        archived = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="ARCHIVE", expires_on=date(2027, 6, 1),
            status="closed")
        self.add(archived, date(2027, 3, 9), "archived")
        self.client.force_login(self.owner)
        data = self.client.get(self.url, {"day": "2027-03-10"}).json()
        self.assertEqual(data["counts"]["overdue"], 0)

    def test_validation_and_methods(self):
        self.client.force_login(self.owner)
        for params in ({}, {"day": "2027-2-3"}, {"day": "2027-02-30"},
                       {"day": "2027-03-10", "scope": "invalid"},
                       {"day": "2027-03-10", "other": "x"},
                       {"day": "2027-03-10", "page": "-1"},
                       {"day": "2027-03-10", "page_size": "0"}):
            self.assertEqual(self.client.get(self.url, params).status_code, 400, params)
        self.assertEqual(self.client.post(self.url, {}).status_code, 405)

    def test_anonymous_and_page_size(self):
        self.add(self.mine, date(2027, 3, 8), "one")
        self.add(self.mine, date(2027, 3, 9), "two")
        self.assertIn(self.client.get(self.url, {"day": "2027-03-10"}).status_code,
                      (401, 403))
        self.client.force_login(self.owner)
        data = self.client.get(self.url, {
            "day": "2027-03-10", "page_size": "1", "page": "2"}).json()
        self.assertEqual(data["count"], 2)
        self.assertEqual(len(data["results"]), 1)
        self.assertEqual(data["results"][0]["reason"], "DEMO-two")
