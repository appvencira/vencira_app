"""O9b API tests: no delivery, isolated, audit response intent."""
import uuid
from datetime import date, datetime, timezone
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from .models import Renewal, RenewalControlResponse, Workspace, WorkspaceMember


class ManualControlApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_user(username="o9b-owner")
        cls.other = get_user_model().objects.create_user(username="o9b-other")
        cls.ws = Workspace.objects.create(name="O9B demo")
        cls.foreign = Workspace.objects.create(name="O9B other")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(workspace=cls.foreign, user=cls.other, role="owner")
        cls.renewal = Renewal.objects.create(
            workspace=cls.ws, customer_reference="DEMO-ONLY",
            entry="clients", full_name="Persona de prueba",
            expires_on=date(2027, 3, 31),
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def url(self, ws=None):
        return reverse("api-control-responses", kwargs={
            "workspace_id": (ws or self.ws).id,
            "renewal_id": self.renewal.id,
        })

    def payload(self, **changes):
        result = {
            "origin": "manual", "revision": 0,
            "idempotency_key": str(uuid.uuid4()),
            "answer": "yes", "yes_option": "notified_by_client",
            "days_later": None,
        }
        result.update(changes)
        return result

    @patch("reminders.control_response_api.timezone.localdate",
           return_value=date(2027, 1, 10))
    def test_manual_yes_persists_with_identity_not_delivery(self, _):
        data = self.payload()
        response = self.client.post(self.url(), data, format="json")
        self.assertEqual(response.status_code, 201, response.data)
        self.assertFalse(response.data["notice_delivered"])
        self.assertFalse(response.data["notice_scheduled"])
        row = RenewalControlResponse.objects.get()
        self.assertEqual(row.actor, self.owner)
        self.assertEqual(row.answer, "yes")
        self.renewal.refresh_from_db()
        self.assertEqual(self.renewal.status, "pending")
        self.assertEqual(self.client.post(self.url(), data, format="json").status_code, 200)
        self.assertEqual(RenewalControlResponse.objects.count(), 1)
        self.assertEqual(self.client.get(self.url()).data["results"][0]["origin"], "manual")

    @patch("django.utils.timezone.now",
           return_value=datetime(2027, 2, 25, 12, 0, tzinfo=timezone.utc))
    @patch("reminders.control_response_api.timezone.localdate",
           return_value=date(2027, 2, 25))
    def test_no_on_cutoff_rejected_then_prior_day_accepted(self, _localdate, _now):
        data = self.payload(answer="no", yes_option=None, days_later=3)
        response = self.client.post(self.url(), data, format="json")
        self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(RenewalControlResponse.objects.exists())
        valid = self.payload(answer="no", yes_option=None, days_later=2)
        accepted = self.client.post(self.url(), valid, format="json")
        self.assertEqual(accepted.status_code, 201, accepted.data)
        self.assertEqual(accepted.data["repeat_on"], "2027-02-27")
        self.assertFalse(accepted.data["notice_delivered"])
        self.assertEqual(self.client.post(self.url(), valid, format="json").status_code, 200)
        self.assertEqual(self.client.post(
            self.url(), self.payload(revision=0), format="json",
        ).status_code, 409)
        self.assertEqual(RenewalControlResponse.objects.count(), 1)

    def test_unauthorized_and_foreign_tenant(self):
        self.client.force_authenticate(user=self.other)
        self.assertEqual(self.client.post(self.url(), self.payload(), format="json").status_code, 404)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
        self.assertFalse(RenewalControlResponse.objects.exists())

    def test_closed_and_malformed_not_written(self):
        self.assertEqual(self.client.post(
            self.url(), self.payload(origin="automatic"), format="json",
        ).status_code, 400)
        self.renewal.status = "closed"
        self.renewal.save(update_fields=["status"])
        self.assertEqual(self.client.post(
            self.url(), self.payload(), format="json",
        ).status_code, 409)
        self.assertFalse(RenewalControlResponse.objects.exists())

    @patch("reminders.control_response_api.timezone.localdate",
           return_value=date(2027, 1, 10))
    def test_idempotency_conflict_and_revision_fail_closed(self, _):
        initial = self.payload()
        self.assertEqual(
            self.client.post(self.url(), initial, format="json").status_code, 201)
        changed = dict(initial, yes_option="notified_by_mediator")
        self.assertEqual(
            self.client.post(self.url(), changed, format="json").status_code, 409)
        stale = self.payload(revision=0)
        response = self.client.post(self.url(), stale, format="json")
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.data["current_revision"], 1)
        self.assertEqual(RenewalControlResponse.objects.count(), 1)

    @patch("reminders.control_response_api.timezone.localdate",
           return_value=date(2027, 1, 10))
    def test_strict_payload_and_life_review_write_nothing(self, _):
        for changes in (
            {"origin": "automatic"},
            {"revision": True},
            {"yes_option": "invented"},
            {"answer": "no", "yes_option": "notified_by_client", "days_later": 1},
            {"idempotency_key": "not-a-uuid"},
        ):
            with self.subTest(changes=changes):
                response = self.client.post(
                    self.url(), self.payload(**changes), format="json")
                self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(RenewalControlResponse.objects.exists())
        self.renewal.modality = "vida"
        self.renewal.save(update_fields=["modality"])
        response = self.client.post(self.url(), self.payload(), format="json")
        self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(RenewalControlResponse.objects.exists())
