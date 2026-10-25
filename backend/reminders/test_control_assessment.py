"""O9a: control-day projection without recording answers or delivery."""
from datetime import date
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase
from django.urls import reverse
from rest_framework.test import APITestCase

from .control_assessment import assess_control
from .models import (Renewal, RenewalReminderDraft, ReminderCandidate,
                     ReminderPolicy, RenewalAuditEvent, Workspace,
                     WorkspaceMember)


class PureControlAssessmentTests(SimpleTestCase):
    def test_last_eligible_default_day_before_civil_cutoff(self):
        result = assess_control(
            date(2027, 3, 15), [60, 45, 35], as_of=date(2027, 1, 1),
        )
        self.assertEqual(result.cutoff_on, date(2027, 2, 15))
        self.assertEqual(result.control_day, date(2027, 2, 8))
        self.assertEqual(result.control_days_before, 35)
        self.assertEqual(result.status, "control_day_future_preview")
        self.assertEqual(result.reasons, ())

    def test_same_day_is_preview_not_message_sent(self):
        result = assess_control(
            date(2027, 3, 15), [35, 45],
            as_of=date(2027, 2, 8),
        )
        self.assertEqual(result.status, "control_day_today_preview")
        self.assertEqual(result.control_day, date(2027, 2, 8))

    def test_days_20_15_have_no_eligible_pre_cutoff_notice(self):
        result = assess_control(
            date(2027, 3, 15), [20, 15],
            as_of=date(2027, 1, 1),
        )
        self.assertIsNone(result.control_day)
        self.assertEqual(result.status, "manual_review_required")
        self.assertIn("no_notice_before_cutoff", result.reasons)

    def test_late_and_cutoff_past_are_not_auto_rescheduled(self):
        result = assess_control(
            date(2027, 3, 15), [60, 45, 35],
            as_of=date(2027, 2, 16),
        )
        self.assertEqual(result.status, "manual_review_required")
        self.assertIn("informational_cutoff_reached", result.reasons)
        self.assertIn("control_date_already_past_no_execution_evidence", result.reasons)

    def test_30_days_still_before_cutoff_not_confused_with_20(self):
        result = assess_control(
            date(2027, 3, 15), [30, 15],
            as_of=date(2027, 2, 1),
        )
        self.assertEqual(result.control_day, date(2027, 2, 13))
        self.assertEqual(result.control_days_before, 30)

    def test_29_february_and_life_exception(self):
        result = assess_control(
            date(2028, 3, 31), [60, 45, 35],
            as_of=date(2028, 1, 1),
            requires_life_review=True,
        )
        self.assertEqual(result.cutoff_on, date(2028, 2, 29))
        self.assertEqual(result.status, "manual_review_required")
        self.assertIn("life_case_needs_review", result.reasons)

    def test_never_auto_selects_repeat_or_approves_life(self):
        result = assess_control(
            date(2027, 3, 15), [60],
            as_of=date(2027, 1, 1), requires_life_review=True,
        )
        self.assertEqual(result.status, "manual_review_required")
        self.assertIsNotNone(result.control_day)
        with self.assertRaises(TypeError):
            assess_control(date(2027, 3, 15), [60],
                           as_of=date(2027, 1, 1), requires_life_review=1)


class ControlAssessmentApiTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.owner = User.objects.create_user(username="o9-owner")
        cls.member = User.objects.create_user(username="o9-member")
        cls.other_member = User.objects.create_user(username="o9-other-member")
        cls.outsider = User.objects.create_user(username="o9-outsider")
        cls.ws = Workspace.objects.create(name="O9 fictitious workspace")
        cls.other_ws = Workspace.objects.create(name="O9 foreign workspace")
        for user, role in ((cls.owner, "owner"), (cls.member, "member"),
                           (cls.other_member, "member")):
            WorkspaceMember.objects.create(workspace=cls.ws, user=user, role=role)
        WorkspaceMember.objects.create(
            workspace=cls.other_ws, user=cls.outsider, role="owner",
        )
        cls.item = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="SYNTHETIC_O9_A",
            expires_on=date(2027, 3, 15),
        )
        cls.another = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.owner,
            customer_reference="SYNTHETIC_O9_B",
            expires_on=date(2027, 3, 15),
        )
        cls.foreign_item = Renewal.objects.create(
            workspace=cls.other_ws, assigned_to=cls.outsider,
            customer_reference="SYNTHETIC_O9_FOREIGN",
            expires_on=date(2027, 3, 15),
        )

    def url(self, item=None, workspace=None):
        return reverse("api-control-assessment", kwargs={
            "workspace_id": (workspace or self.ws).pk,
            "renewal_id": (item or self.item).pk,
        })

    @patch("reminders.control_assessment_api.timezone.localdate",
           return_value=date(2027, 1, 1))
    def test_default_never_writes_and_no_pii(self, _):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(response.data["control_day"], "2027-02-08")
        self.assertEqual(response.data["informational_cutoff_on"], "2027-02-15")
        self.assertEqual(response.data["status"], "control_day_future_preview")
        self.assertEqual(response.data["days_before"], [60, 45, 35])
        self.assertFalse(response.data["draft_persisted"])
        self.assertEqual(response.data["draft_revision"], 0)
        self.assertTrue(response.data["assessment_only"])
        for key in ("answer_recorded", "scheduled", "delivered"):
            self.assertFalse(response.data[key])
        self.assertNotIn("SYNTHETIC_O9_A", str(response.data))
        self.assertFalse(RenewalReminderDraft.objects.exists())
        self.assertFalse(ReminderCandidate.objects.exists())
        self.assertFalse(ReminderPolicy.objects.exists())
        self.assertFalse(RenewalAuditEvent.objects.exists())

    @patch("reminders.control_assessment_api.timezone.localdate",
           return_value=date(2027, 1, 1))
    def test_saved_draft_takes_precedence_and_not_modified(self, _):
        draft = RenewalReminderDraft.objects.create(
            renewal=self.item, days_before=[20, 15], revision=3,
            state="draft", created_by=self.owner, updated_by=self.member,
        )
        self.client.force_authenticate(user=self.member)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["status"], "manual_review_required")
        self.assertEqual(response.data["reasons"], ["no_notice_before_cutoff"])
        self.assertEqual(response.data["days_before"], [20, 15])
        self.assertTrue(response.data["draft_persisted"])
        self.assertEqual(response.data["draft_revision"], 3)
        self.assertIsNone(response.data["control_day"])
        draft.refresh_from_db()
        self.assertEqual(draft.revision, 3)
        self.assertFalse(ReminderCandidate.objects.exists())
        self.assertFalse(RenewalAuditEvent.objects.exists())

    def test_unauthorized_cross_workspace_and_nonassigned(self):
        self.client.force_authenticate(user=self.other_member)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.get(self.url(
            item=self.foreign_item, workspace=self.other_ws,
        )).status_code, 404)
        self.client.force_authenticate(user=self.outsider)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.url(item=self.another)).status_code, 200)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))

    def test_no_input_or_writes_allowed_and_archived_rejected(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.url(), {"days": "35"}).status_code, 400)
        self.assertEqual(self.client.post(self.url(), {}, format="json").status_code, 405)
        self.assertEqual(self.client.put(self.url(), {}, format="json").status_code, 405)
        self.item.status = Renewal.Status.CLOSED
        self.item.save(update_fields=["status"])
        blocked = self.client.get(self.url())
        self.assertEqual(blocked.status_code, 409)
        self.assertEqual(blocked["Cache-Control"], "no-store")
        self.assertFalse(RenewalReminderDraft.objects.exists())
