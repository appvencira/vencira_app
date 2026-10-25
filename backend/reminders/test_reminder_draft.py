"""O8c: draft-only scoped rules, revisions, conflict and no sends."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient, APITestCase

from .models import (ReminderCandidate, ReminderPolicy, Renewal,
                     RenewalReminderDraft, Workspace, WorkspaceMember)


class ReminderDraftApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.owner = User.objects.create_user(
            username="o8c-owner", password="O8c-demo-only-1!")
        cls.assignee = User.objects.create_user(
            username="o8c-assignee", password="O8c-demo-only-2!")
        cls.colleague = User.objects.create_user(
            username="o8c-colleague", password="O8c-demo-only-3!")
        cls.foreign = User.objects.create_user(
            username="o8c-foreign", password="O8c-demo-only-4!")
        cls.ws = Workspace.objects.create(name="Draft DEMO 1")
        cls.other_ws = Workspace.objects.create(name="Draft DEMO 2")
        for user, role in ((cls.owner, "owner"), (cls.assignee, "member"),
                           (cls.colleague, "member")):
            WorkspaceMember.objects.create(
                workspace=cls.ws, user=user, role=role)
        WorkspaceMember.objects.create(
            workspace=cls.other_ws, user=cls.foreign, role="owner")
        cls.item = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.assignee,
            customer_reference="NO_EXPOSICION_PII_DEMO",
            expires_on=date(2027, 3, 15))
        cls.second = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.owner,
            customer_reference="OTRA_ANOTACION_FICTICIA",
            expires_on=date(2027, 6, 30))
        cls.foreign_item = Renewal.objects.create(
            workspace=cls.other_ws, assigned_to=cls.foreign,
            customer_reference="TENANT_DISTINTO_DEMO",
            expires_on=date(2027, 3, 15))

    def url(self, ws=None, item=None):
        return reverse("api-reminder-draft", kwargs={
            "workspace_id": (ws or self.ws).pk,
            "renewal_id": (item or self.item).pk,
        })

    def _payload(self, days=None, rev=0, state="draft"):
        return {"state": state, "revision": rev,
                "days_before": [20, 15] if days is None else days}

    def test_get_returns_unpersisted_defaults_without_changes(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(response.data["revision"], 0)
        self.assertEqual(response.data["days_before"], [60, 45, 35])
        self.assertFalse(response.data["is_persisted"])
        self.assertEqual(response.data["state"], "draft")
        self.assertFalse(response.data["scheduling_enabled"])
        self.assertFalse(response.data["delivered"])
        self.assertNotIn("NO_EXPOSICION_PII_DEMO", str(response.data))
        self.assertFalse(RenewalReminderDraft.objects.exists())
        self.assertFalse(ReminderPolicy.objects.exists())
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_save_draft_is_per_renewal_normalized_and_idempotent(self):
        self.client.force_authenticate(user=self.assignee)
        response = self.client.put(self.url(), self._payload([15, 20]), format="json")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["is_persisted"])
        self.assertEqual(response.data["revision"], 1)
        self.assertEqual(response.data["days_before"], [20, 15])
        self.assertTrue(response.data["no_pre_cutoff_notice"])
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertFalse(response.data["scheduling_enabled"])
        self.assertFalse(response.data["delivered"])
        self.assertEqual(RenewalReminderDraft.objects.count(), 1)
        row = RenewalReminderDraft.objects.get(renewal=self.item)
        self.assertEqual(row.created_by, self.assignee)
        self.assertEqual(row.updated_by, self.assignee)
        self.assertEqual(row.state, "draft")

        # PUT con idéntico contenido y revisión vigente no incrementa versión.
        repeat = self.client.put(
            self.url(), self._payload([20, 15], rev=1), format="json")
        self.assertEqual(repeat.status_code, 200)
        self.assertEqual(repeat.data["revision"], 1)
        self.assertEqual(RenewalReminderDraft.objects.count(), 1)
        other = self.client.get(self.url(item=self.second))
        self.assertEqual(other.status_code, 404)  # No asignada al empleado.
        self.client.force_authenticate(user=self.owner)
        other = self.client.get(self.url(item=self.second))
        self.assertEqual(other.status_code, 200)
        self.assertEqual(other.data["days_before"], [60, 45, 35])
        self.assertFalse(other.data["is_persisted"])
        self.assertFalse(ReminderPolicy.objects.exists())
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_revision_conflict_prevents_lost_update(self):
        self.client.force_authenticate(user=self.owner)
        start = self.client.put(self.url(), self._payload(), format="json")
        self.assertEqual(start.status_code, 200)
        fresh = self.client.put(
            self.url(), self._payload([90, 60, 35], rev=1),
            format="json")
        self.assertEqual(fresh.status_code, 200)
        self.assertEqual(fresh.data["revision"], 2)
        stale = self.client.put(
            self.url(), self._payload([180, 45], rev=1),
            format="json")
        self.assertEqual(stale.status_code, 409)
        self.assertEqual(stale["Cache-Control"], "no-store")
        self.assertEqual(stale.data["current_revision"], 2)
        current = self.client.get(self.url())
        self.assertEqual(current.data["days_before"], [90, 60, 35])
        self.assertEqual(current.data["revision"], 2)
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_security_boundaries_member_owner_cross_tenant_anonymous(self):
        self.client.force_authenticate(user=self.colleague)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.assertEqual(self.client.put(
            self.url(), self._payload(), format="json").status_code, 404)
        self.client.force_authenticate(user=self.assignee)
        self.assertEqual(self.client.get(
            self.url(ws=self.other_ws, item=self.foreign_item)).status_code, 404)
        self.assertEqual(self.client.put(
            self.url(ws=self.other_ws, item=self.foreign_item),
            self._payload(), format="json").status_code, 404)
        self.client.force_authenticate(user=self.foreign)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.assertEqual(self.client.put(
            self.url(), self._payload(), format="json").status_code, 404)
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.url(item=self.second)).status_code, 200)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
        self.assertIn(self.client.put(
            self.url(), self._payload(), format="json").status_code, (401, 403))
        self.assertFalse(RenewalReminderDraft.objects.exists())

    def test_reject_invalid_payloads_fail_closed(self):
        self.client.force_authenticate(user=self.owner)
        cases = [
            self._payload([], 0),
            self._payload(list(range(13))),
            self._payload([35, 35]),
            self._payload([366]),
            self._payload([-1]),
            self._payload(["35"]),
            self._payload([True]),
            self._payload([1.5]),
            self._payload(None, True),
            self._payload(None, -1),
            self._payload(None, 2147483647),
            self._payload(None, 0, "enabled"),
            self._payload(None, 0, "paused"),
            {"days_before": [60, 45, 35], "revision": 0},
            {**self._payload(), "extra": "true"},
        ]
        for payload in cases:
            with self.subTest(payload=payload):
                result = self.client.put(self.url(), payload, format="json")
                self.assertEqual(result.status_code, 400)
                self.assertEqual(result["Cache-Control"], "no-store")
        result = self.client.put(self.url(), {"state": "draft", "revision": "0",
                        "days_before": [60]}, format="json")
        self.assertEqual(result.status_code, 400)
        self.assertEqual(RenewalReminderDraft.objects.count(), 0)
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_read_write_methods_must_be_safe_and_no_query_params(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.post(self.url(), {}, format="json").status_code, 405)
        self.assertEqual(self.client.patch(self.url(), {}, format="json").status_code, 405)
        self.assertEqual(self.client.delete(self.url()).status_code, 405)
        self.assertEqual(self.client.get(self.url(), {"days": "35"}).status_code, 400)
        self.assertEqual(self.client.put(
            self.url(), self._payload(), format="multipart").status_code, 400)
        self.assertFalse(RenewalReminderDraft.objects.exists())

    def test_closed_or_archived_conflict_without_side_effect(self):
        self.client.force_authenticate(user=self.owner)
        self.item.status = Renewal.Status.CLOSED
        self.item.save(update_fields=["status"])
        self.assertEqual(self.client.get(self.url()).status_code, 409)
        self.assertEqual(self.client.put(
            self.url(), self._payload(), format="json").status_code, 409)
        self.item.status = Renewal.Status.PENDING
        self.item.archived_at = __import__("django.utils.timezone",
                                           fromlist=["now"]).now()
        self.item.save(update_fields=["status", "archived_at"])
        self.assertEqual(self.client.get(self.url()).status_code, 409)
        self.assertEqual(self.client.put(
            self.url(), self._payload(), format="json").status_code, 409)
        self.assertFalse(RenewalReminderDraft.objects.exists())

    def test_missing_csrf_rejected_for_logged_in_session(self):
        client = APIClient(enforce_csrf_checks=True)
        self.assertTrue(client.login(
            username="o8c-owner", password="O8c-demo-only-1!"))
        response = client.put(self.url(), self._payload(), format="json")
        self.assertEqual(response.status_code, 403)
        self.assertFalse(RenewalReminderDraft.objects.exists())
