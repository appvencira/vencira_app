"""Device notice *preview* must never become a delivery or bulk export."""
from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from reminders.models import (
    OperationalReminder, OperationalReminderEvent, Renewal, Workspace,
    WorkspaceMember,
)


class DeviceNoticePreviewTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="notice_owner", password="test")
        self.member = User.objects.create_user(username="notice_member", password="test")
        self.stranger = User.objects.create_user(username="notice_stranger", password="test")
        self.ws = Workspace.objects.create(name="Notification previews")
        self.foreign = Workspace.objects.create(name="Other")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.owner, role="owner")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.member, role="member")
        WorkspaceMember.objects.create(workspace=self.foreign, user=self.stranger, role="owner")
        self.mine = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.member,
            customer_reference="SYNTHETIC-MEMBER",
            expires_on=date(2027, 5, 31))
        self.owners = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="SYNTHETIC-OWNER",
            expires_on=date(2027, 6, 1))
        self.other = Renewal.objects.create(
            workspace=self.foreign, assigned_to=self.stranger,
            customer_reference="FOREIGN-HIDDEN",
            expires_on=date(2027, 6, 1))
        self.url = reverse("api-device-notice-preview",
                           kwargs={"workspace_id": self.ws.pk})
        self.query = {"from": "2027-03-01", "through": "2027-03-31"}

    def add(self, renewal, day, suffix, state="planned"):
        return OperationalReminder.objects.create(
            renewal=renewal, kind=OperationalReminder.Kind.EXPIRY,
            source_key="test:" + suffix, generation=1,
            scheduled_for=day, original_scheduled_for=day,
            reason="Reminder " + suffix, state=state)

    def test_owner_reads_bounded_occurrences_without_delivery_or_pii(self):
        visible = self.add(self.mine, date(2027, 3, 8), "mine")
        self.add(self.owners, date(2027, 3, 10), "owner", "snoozed")
        self.add(self.owners, date(2027, 3, 9), "done", "completed")
        self.add(self.other, date(2027, 3, 8), "secret")
        self.add(self.mine, date(2027, 4, 1), "later")
        self.client.force_login(self.owner)
        response = self.client.get(self.url, self.query)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        body = response.json()
        self.assertEqual(body["count"], 2)
        self.assertEqual(body["timezone"], "Europe/Madrid")
        self.assertEqual(body["capabilities"], {
            "native_alarm_scheduling": False,
            "offline_storage": False,
            "delivery": False,
        })
        self.assertEqual(body["results"][0]["id"], str(visible.pk))
        self.assertTrue(all(x["delivery_status"] == "not_implemented"
                            for x in body["results"]))
        self.assertTrue(all("email" not in x and "phone" not in x
                            and "customer_reference" not in x
                            for x in body["results"]))
        self.assertFalse(OperationalReminderEvent.objects.exists())
        self.assertEqual(OperationalReminder.objects.count(), 5)

    def test_member_and_foreign_workspace_visibility(self):
        mine = self.add(self.mine, date(2027, 3, 8), "mine")
        self.add(self.owners, date(2027, 3, 8), "owner")
        self.add(self.other, date(2027, 3, 8), "foreign")
        self.client.force_login(self.member)
        response = self.client.get(self.url, self.query)
        self.assertEqual([x["id"] for x in response.json()["results"]],
                         [str(mine.pk)])
        self.client.force_login(self.stranger)
        self.assertEqual(self.client.get(self.url, self.query).status_code, 404)

    def test_rejects_invalid_or_unbounded_calendar(self):
        self.client.force_login(self.owner)
        invalid = (
            {}, {"from": "2027-03-01"}, 
            {"from": "2027-03-01", "through": "2027-04-01"},
            {"from": "2027-03-10", "through": "2027-03-09"},
            {"from": "2027-3-1", "through": "2027-03-31"},
            {"from": "2027-02-30", "through": "2027-03-31"},
            {"from": "2027-03-01", "through": "2027-03-31", "page": "0"},
            {"from": "2027-03-01", "through": "2027-03-31", "page": "true"},
            {"from": "2027-03-01", "through": "2027-03-31", "extra": "x"},
        )
        for params in invalid:
            with self.subTest(params=params):
                self.assertEqual(self.client.get(self.url, params).status_code, 400)
        self.assertEqual(self.client.post(self.url, self.query).status_code, 405)

    def test_pagination_has_no_silent_truncation(self):
        for i in range(51):
            self.add(self.mine, date(2027, 3, 8), str(i))
        self.client.force_login(self.owner)
        response = self.client.get(self.url, self.query)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], 51)
        self.assertEqual(len(response.json()["results"]), 50)
        self.assertIsNotNone(response.json()["next"])
        second = self.client.get(self.url, {**self.query, "page": "2"}).json()
        self.assertEqual(len(second["results"]), 1)
        self.assertIsNone(second["next"])

    def test_no_anonymous_export(self):
        self.add(self.mine, date(2027, 3, 8), "mine")
        self.assertIn(self.client.get(self.url, self.query).status_code, (401, 403))
