"""Auditoría de escrituras realista, mínima, aislada y atómica."""
from datetime import date
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from .models import Renewal, RenewalAuditEvent, Workspace, WorkspaceMember


class RenewalAuditTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.owner = get_user_model().objects.create_user(
            username="audit-owner", password="Audit-Local-Only-Password!"
        )
        cls.other = get_user_model().objects.create_user(
            username="audit-other", password="Audit-Local-Only-Password!"
        )
        cls.a = Workspace.objects.create(name="Auditoría A")
        cls.b = Workspace.objects.create(name="Auditoría B")
        WorkspaceMember.objects.create(
            workspace=cls.a, user=cls.owner, role=WorkspaceMember.Role.OWNER
        )
        WorkspaceMember.objects.create(
            workspace=cls.b, user=cls.other, role=WorkspaceMember.Role.OWNER
        )
        cls.existing = Renewal.objects.create(
            workspace=cls.a, customer_reference="TOKEN-SECRETO-DEMO",
            expires_on=date(2027, 3, 20),
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def _create_url(self, workspace=None):
        return reverse("api-renewals", kwargs={"workspace_id": (workspace or self.a).pk})

    def _detail_url(self, renewal, workspace=None):
        return reverse("api-renewal-detail", kwargs={
            "workspace_id": (workspace or self.a).pk,
            "renewal_id": renewal.pk,
        })

    def test_creation_creates_one_event_with_actor_tenant_and_no_reference_value(self):
        response = self.client.post(self._create_url(), {
            "customer_reference": "REFERENCIA-PRIVADA-12345",
            "expires_on": "2027-02-27",
            "status": "pending",
        }, format="json")
        self.assertEqual(response.status_code, 201)
        event = RenewalAuditEvent.objects.get()
        self.assertEqual(event.actor, self.owner)
        self.assertEqual(event.workspace, self.a)
        self.assertEqual(str(event.renewal_id), str(response.data["id"]))
        self.assertEqual(event.action, "created")
        self.assertEqual(set(event.changed_fields), {"customer_reference", "expires_on", "status", "assigned_to_id"})
        self.assertNotIn("REFERENCIA-PRIVADA-12345", str(event.metadata))
        self.assertNotIn("customer_reference", event.metadata)
        self.assertEqual(event.metadata["expires_on"]["after"], "2027-02-27")

    def test_patch_event_contains_before_and_after_nonpersonal_fields(self):
        response = self.client.patch(self._detail_url(self.existing), {
            "customer_reference": "OTRO-SECRETO-DEMO",
            "expires_on": "2027-04-20", "status": "contacted",
        }, format="json")
        self.assertEqual(response.status_code, 200)
        event = RenewalAuditEvent.objects.get()
        self.assertEqual(event.action, "updated")
        self.assertEqual(event.changed_fields, ["customer_reference", "expires_on", "status"])
        self.assertEqual(event.metadata["expires_on"], {"before": "2027-03-20", "after": "2027-04-20"})
        self.assertEqual(event.metadata["status"], {"before": "pending", "after": "contacted"})
        self.assertNotIn("OTRO-SECRETO-DEMO", str(event.metadata))
        self.assertNotIn("TOKEN-SECRETO-DEMO", str(event.metadata))

    def test_identical_and_empty_patch_create_no_event(self):
        for data in ({}, {"status": "pending"}, {"customer_reference": "TOKEN-SECRETO-DEMO"}):
            response = self.client.patch(self._detail_url(self.existing), data, format="json")
            self.assertEqual(response.status_code, 200)
        self.assertFalse(RenewalAuditEvent.objects.exists())

    def test_rejected_write_and_cross_workspace_request_leave_no_trace(self):
        bad = self.client.post(self._create_url(), {
            "customer_reference": "X",
            "expires_on": "2027-03-01",
            "workspace_id": str(self.b.pk),
        }, format="json")
        self.assertEqual(bad.status_code, 400)
        attempt = self.client.patch(
            self._detail_url(self.existing, workspace=self.b),
            {"status": "closed"}, format="json",
        )
        self.assertEqual(attempt.status_code, 404)
        self.assertFalse(RenewalAuditEvent.objects.exists())

    def test_immutable_fields_and_unknown_fields_rejected(self):
        for payload in ({"id": str(self.existing.pk)}, {"extra": 1},
                        {"created_at": "2025-01-01"}, {"workspace": str(self.b.pk)}):
            with self.subTest(payload=payload):
                response = self.client.patch(
                    self._detail_url(self.existing), payload, format="json"
                )
                self.assertEqual(response.status_code, 400)
        self.assertFalse(RenewalAuditEvent.objects.exists())

    def test_transaction_rolls_back_both_data_and_audit(self):
        before_count = Renewal.objects.count()
        with patch("reminders.audit.RenewalAuditEvent.objects.create", side_effect=RuntimeError("audit-write-error")):
            with self.assertRaises(RuntimeError):
                self.client.post(self._create_url(), {
                    "customer_reference": "NO-DEBE-GUARDARSE",
                    "expires_on": "2027-03-01",
                }, format="json")
        self.assertEqual(Renewal.objects.count(), before_count)
        self.assertFalse(RenewalAuditEvent.objects.exists())

    def test_non_api_legacy_rows_do_not_falsely_claim_audited(self):
        self.assertEqual(Renewal.objects.count(), 1)
        self.assertEqual(RenewalAuditEvent.objects.count(), 0)
