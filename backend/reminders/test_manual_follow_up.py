"""O2: tenant isolation, civil dates, audit, CSRF and agenda visibility."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from .models import Renewal, RenewalAuditEvent, RenewalFollowUp, Workspace, WorkspaceMember


class ManualFollowUpTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model().objects
        cls.owner = users.create_user(username="follow-owner", password="Demo-Pw!2026")
        cls.member = users.create_user(username="follow-member", password="Demo-Pw!2026")
        cls.other = users.create_user(username="follow-other", password="Demo-Pw!2026")
        cls.ws = Workspace.objects.create(name="O2 test")
        cls.foreign = Workspace.objects.create(name="Other O2 test")
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.member, role="member")
        WorkspaceMember.objects.create(
            workspace=cls.foreign, user=cls.other, role="owner")
        cls.item = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="SYNTHETIC-1", expires_on=date(2027, 6, 15))
        cls.other_item = Renewal.objects.create(
            workspace=cls.foreign, assigned_to=cls.other,
            customer_reference="OTHER", expires_on=date(2027, 6, 15))

    def url(self, ws=None, item=None):
        return reverse("api-manual-follow-up", kwargs={
            "workspace_id": (ws or self.ws).id,
            "renewal_id": (item or self.item).id,
        })

    def test_create_read_repeat_reschedule_complete_and_audit(self):
        self.client.force_authenticate(self.member)
        url = self.url()
        self.assertIsNone(self.client.get(url).data["active"])
        one = self.client.post(url, {"scheduled_for": "2027-05-21"}, format="json")
        self.assertEqual(one.status_code, 201)
        first_id = one.data["active"]["id"]
        self.assertEqual(
            self.client.post(url, {"scheduled_for": "2027-05-21"},
                             format="json").data["active"]["id"], first_id)
        self.assertEqual(RenewalAuditEvent.objects.filter(
            renewal=self.item, changed_fields=["manual_follow_up"]).count(), 1)
        two = self.client.post(url, {"scheduled_for": "2027-05-24"}, format="json")
        self.assertEqual(two.status_code, 201)
        self.assertNotEqual(two.data["active"]["id"], first_id)
        self.assertEqual(RenewalFollowUp.objects.filter(
            renewal=self.item, state="planned").count(), 1)
        self.assertEqual(RenewalFollowUp.objects.get(pk=first_id).state, "cancelled")
        old = self.client.patch(url, {"id": first_id, "action": "complete"}, format="json")
        self.assertEqual(old.status_code, 409)
        done = self.client.patch(url, {
            "id": two.data["active"]["id"], "action": "complete"}, format="json")
        self.assertEqual(done.status_code, 200)
        self.assertIsNone(self.client.get(url).data["active"])
        self.assertEqual(RenewalFollowUp.objects.filter(
            renewal=self.item, state="completed").count(), 1)
        self.assertEqual(RenewalAuditEvent.objects.filter(
            renewal=self.item, changed_fields=["manual_follow_up"]).count(), 3)
        self.item.refresh_from_db()
        self.assertEqual(self.item.expires_on, date(2027, 6, 15))
        self.assertEqual(self.item.status, "pending")

    def test_cancel_keeps_record_and_reprogram_afterwards(self):
        self.client.force_authenticate(self.owner)
        url = self.url()
        planned = self.client.post(url, {"scheduled_for": "2027-05-20"},
                                   format="json").data["active"]
        closed = self.client.patch(
            url, {"id": planned["id"], "action": "cancel"}, format="json")
        self.assertEqual(closed.status_code, 200)
        self.assertEqual(RenewalFollowUp.objects.get(pk=planned["id"]).state,
                         "cancelled")
        self.assertIsNone(closed.data["active"])
        self.assertEqual(self.client.post(
            url, {"scheduled_for": "2027-05-22"}, format="json").status_code, 201)

    def test_reject_invalid_dates_and_extra_fields(self):
        self.client.force_authenticate(self.member)
        for payload in (
            {"scheduled_for": "2027-02-30"},
            {"scheduled_for": "2027-5-1"},
            {"scheduled_for": "1899-01-01"},
            {"scheduled_for": "2027-05-01", "workspace": str(self.foreign.id)},
            {"scheduled_for": 20270501},
        ):
            with self.subTest(payload=payload):
                self.assertEqual(self.client.post(
                    self.url(), payload, format="json").status_code, 400)
        self.assertFalse(RenewalFollowUp.objects.exists())

    def test_scope_denies_foreign_and_unassigned_members(self):
        self.client.force_authenticate(self.member)
        for method in ("get", "post", "patch"):
            url = self.url(self.foreign, self.other_item)
            args = {"scheduled_for": "2027-05-21"} if method == "post" else {
                "id": "00000000-0000-4000-8000-000000000000",
                "action": "cancel"}
            response = getattr(self.client, method)(url,
                **({"data": args, "format": "json"} if method != "get" else {}))
            self.assertEqual(response.status_code, 404)
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(self.url()).status_code, 404)

    def test_closed_item_cannot_create_follow_up(self):
        self.item.status = Renewal.Status.CLOSED
        self.item.save(update_fields=["status"])
        self.client.force_authenticate(self.owner)
        self.assertEqual(self.client.post(
            self.url(), {"scheduled_for": "2027-05-21"}, format="json").status_code, 409)

    def test_daily_monthly_agenda_only_visible_followups(self):
        self.client.force_authenticate(self.member)
        self.client.post(self.url(), {"scheduled_for": "2027-05-21"}, format="json")
        day = reverse("api-agenda-day", kwargs={"workspace_id": self.ws.id})
        month = reverse("api-agenda-month", kwargs={"workspace_id": self.ws.id})
        response = self.client.get(day, {"day": "2027-05-21"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["events"],
                         [{"kind": "follow_up"}])
        days = self.client.get(month, {"month": "2027-05"})
        self.assertEqual(days.status_code, 200)
        self.assertEqual(days.data["days"][0]["follow_up"],
                         {"pending": 1, "contacted": 0})
        self.client.force_authenticate(self.other)
        self.assertEqual(self.client.get(day.replace(str(self.ws.id),
            str(self.foreign.id)), {"day": "2027-05-21"}).data["count"], 0)

    def test_anonymous_denied_and_session_csrf_required(self):
        url = self.url()
        self.assertIn(self.client.get(url).status_code, (401, 403))
        client = APIClient(enforce_csrf_checks=True)
        client.force_login(self.owner)
        response = client.post(url, {"scheduled_for": "2027-05-21"},
                               format="json")
        self.assertEqual(response.status_code, 403)
        self.assertFalse(RenewalFollowUp.objects.exists())
