"""O8b: API preview, autorización multi-cuenta y ausencia de escrituras."""
from datetime import date
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import ReminderCandidate, ReminderPolicy, Renewal, Workspace, WorkspaceMember


class ReminderPreviewApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        Users = get_user_model()
        cls.owner = Users.objects.create_user(username="preview-owner")
        cls.assignee = Users.objects.create_user(username="preview-assignee")
        cls.other_user = Users.objects.create_user(username="preview-other")
        cls.foreign = Users.objects.create_user(username="preview-foreign")
        cls.ws = Workspace.objects.create(name="Demo preview")
        cls.foreign_ws = Workspace.objects.create(name="Otra cuenta demo")
        for user, role in ((cls.owner, "owner"), (cls.assignee, "member"),
                           (cls.other_user, "member")):
            WorkspaceMember.objects.create(workspace=cls.ws, user=user, role=role)
        WorkspaceMember.objects.create(
            workspace=cls.foreign_ws, user=cls.foreign, role="owner")
        cls.item = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.assignee,
            customer_reference="REFERENCIA_FICTICIA_A",
            expires_on=date(2027, 3, 15))
        cls.foreign_item = Renewal.objects.create(
            workspace=cls.foreign_ws, assigned_to=cls.foreign,
            customer_reference="REFERENCIA_FICTICIA_B",
            expires_on=date(2027, 3, 15))

    def url(self, ws=None, item=None):
        return reverse("api-reminder-preview", kwargs={
            "workspace_id": (ws or self.ws).pk,
            "renewal_id": (item or self.item).pk})

    @patch("reminders.reminder_preview.timezone.localdate",
           return_value=date(2027, 1, 1))
    def test_default_view_authorized_and_no_database_writes(self, _):
        for user in (self.owner, self.assignee):
            self.client.force_authenticate(user=user)
            response = self.client.get(self.url())
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data["informational_cutoff_on"], "2027-02-15")
            self.assertEqual([x["days_before"] for x in response.data["reminders"]],
                             [60, 45, 35])
            self.assertEqual([x["days_before"] for x in response.data["reminders"]
                              if x["control_question"]], [35])
            self.assertTrue(response.data["preview_only"])
            self.assertFalse(response.data["delivered"])
            self.assertEqual(response["Cache-Control"], "no-store")
            self.assertNotIn("REFERENCIA_FICTICIA_A", str(response.data))
        self.assertFalse(ReminderCandidate.objects.exists())
        self.assertFalse(ReminderPolicy.objects.exists())

    @patch("reminders.reminder_preview.timezone.localdate",
           return_value=date(2027, 2, 9))
    def test_custom_late_controls_and_missing_notice(self, _):
        self.client.force_authenticate(user=self.assignee)
        response = self.client.get(self.url(), {"days": "15,30"})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["no_pre_cutoff_notice"])
        response = self.client.get(self.url(), {"days": "35,45,60"})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["late_control_needs_decision"])

    def test_invalid_queries_and_non_get_blocked(self):
        self.client.force_authenticate(user=self.owner)
        for params in ({"days": "35,35"}, {"days": "366"},
                       {"days": ""}, {"days": "1,,2"},
                       {"days": "-1"}, {"days": "1", "unknown": "x"},
                       {"days": ["35", "45"]}):
            with self.subTest(params=params):
                self.assertEqual(self.client.get(self.url(), params).status_code, 400)
        self.assertEqual(self.client.post(self.url(), {"days": "60"}).status_code, 405)

    def test_closed_annotations_not_schedulable_and_life_warning(self):
        self.client.force_authenticate(user=self.owner)
        self.item.modality = "vida"
        self.item.save(update_fields=["modality"])
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["life_rule_requires_review"])
        self.item.status = "closed"
        self.item.save(update_fields=["status"])
        rejected = self.client.get(self.url())
        self.assertEqual(rejected.status_code, 409)
        self.assertEqual(rejected["Cache-Control"], "no-store")
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_authorization_and_account_boundaries(self):
        self.client.force_authenticate(user=self.other_user)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=self.assignee)
        self.assertEqual(self.client.get(
            self.url(ws=self.foreign_ws, item=self.foreign_item)).status_code, 404)
        self.client.force_authenticate(user=self.foreign)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
