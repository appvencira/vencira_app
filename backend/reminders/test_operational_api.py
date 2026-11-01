"""Multi-tenant and ownership visibility for internal reminder reads."""
from datetime import date
import json
import uuid
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from reminders.models import Workspace, WorkspaceMember, Renewal, OperationalReminder, OperationalReminderEvent

class OperationalApiTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username="own_a", password="test-str0ng-a!")
        self.other = User.objects.create_user(username="own_b", password="test-str0ng-b!")
        self.ws = Workspace.objects.create(name="A")
        self.ws_other = Workspace.objects.create(name="B")
        WorkspaceMember.objects.create(workspace=self.ws, user=self.owner, role="owner")
        WorkspaceMember.objects.create(workspace=self.ws_other, user=self.other, role="owner")
        self.renewal = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="FICTICIO", expires_on=date(2027, 3, 15))
        self.reminder = OperationalReminder.objects.create(
            renewal=self.renewal, kind="expiry", source_key="expiry:35",
            scheduled_for=date(2027, 2, 8),
            original_scheduled_for=date(2027, 2, 8),
            reason="Aviso ficticio", days_before=35)
        self.url = reverse("api-operational-reminders",
            kwargs={"workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})

    def test_authenticated_non_owner_403_is_not_expired_session(self):
        # Same valid login, but a workspace role restriction. This is not
        # evidence of an expired session and must not be used as such.
        WorkspaceMember.objects.create(
            workspace=self.ws, user=self.other, role="member")
        self.client.force_login(self.other)
        url = reverse("api-workspace-members",
            kwargs={"workspace_id": self.ws.pk})
        self.assertEqual(self.client.get(url).status_code, 403)
        self.assertEqual(self.client.get(reverse("api-me")).status_code, 200)

    def test_missing_workspace_membership_is_concealed_not_session_expiry(self):
        self.client.force_login(self.other)
        url = reverse("api-workspace-members",
            kwargs={"workspace_id": self.ws.pk})
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.get(reverse("api-me")).status_code, 200)

    def test_anonymous_identity_and_membership_are_not_authenticated(self):
        self.client.logout()
        identity = self.client.get(reverse("api-me"))
        membership = self.client.get(reverse("api-workspace-members",
            kwargs={"workspace_id": self.ws.pk}))
        # DRF SessionAuthentication may report 403 without a WWW-Authenticate
        # challenge. Record actual denial, not an invented universal 401.
        self.assertIn(identity.status_code, (401, 403))
        self.assertIn(membership.status_code, (401, 403))
        self.assertNotEqual(identity.status_code, 200)
        self.assertNotEqual(membership.status_code, 200)

    def test_logout_invalidates_identity_while_role_denial_does_not(self):
        WorkspaceMember.objects.create(
            workspace=self.ws, user=self.other, role="member")
        self.client.force_login(self.other)
        members_url = reverse("api-workspace-members",
            kwargs={"workspace_id": self.ws.pk})
        self.assertEqual(self.client.get(members_url).status_code, 403)
        self.assertEqual(self.client.get(reverse("api-me")).status_code, 200)
        self.client.logout()
        self.assertIn(self.client.get(reverse("api-me")).status_code,
                      (401, 403))

    def test_authorized_owner_reads_only_internal_occurrences(self):
        self.client.force_login(self.owner)
        result = self.client.get(self.url)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(len(result.json()["results"]), 1)
        self.assertEqual(result.json()["results"][0]["delivery_status"], "not_implemented")
        self.assertEqual(result["Cache-Control"], "no-store")

    def test_unrelated_user_cannot_read_or_write(self):
        self.client.force_login(self.other)
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(self.client.post(self.url, data={}).status_code, 405)

    def test_method_and_query_rejected(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.client.post(self.url, data={}).status_code, 405)
        self.assertEqual(self.client.get(self.url + "?unsafe=1").status_code, 400)

    def action(self, user, *, key=None, state="planned", day="2027-02-08",
               action="complete", days=None):
        self.client.force_login(user)
        url = reverse("api-operational-reminder-action", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "reminder_id": self.reminder.pk})
        return self.client.post(url, data=json.dumps({
            "action": action, "expected_state": state, "expected_day": day,
            "idempotency_key": str(key or uuid.uuid4()), "days_later": days,
        }), content_type="application/json")

    def test_action_succeeds_and_replay_is_idempotent(self):
        key = uuid.uuid4()
        first = self.action(self.owner, key=key)
        second = self.action(self.owner, key=key)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(first.json()["state"], "completed")
        self.assertEqual(first.json()["delivery_status"], "not_implemented")

    def test_action_stale_conflict(self):
        self.assertEqual(self.action(self.owner).status_code, 200)
        self.assertEqual(self.action(self.owner).status_code, 409)

    def test_action_other_workspace_is_not_visible(self):
        self.assertEqual(self.action(self.other).status_code, 404)

    def test_action_rejects_bad_json_contract(self):
        self.client.force_login(self.owner)
        url = reverse("api-operational-reminder-action", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "reminder_id": self.reminder.pk})
        self.assertEqual(self.client.post(
            url, data=json.dumps({"action": "complete"}),
            content_type="application/json").status_code, 400)

    @patch("reminders.operational_transitions.timezone.localdate",
           return_value=date(2027, 2, 8))
    def test_tomorrow_moves_inbox_day_and_audits_once(self, _today):
        first = self.action(self.owner, action="tomorrow")
        self.assertEqual(first.status_code, 200, first.content)
        self.assertEqual(first.json()["state"], "snoozed")
        self.assertEqual(first.json()["scheduled_for"], "2027-02-09")
        self.assertEqual(first.json()["delivery_status"], "not_implemented")
        event = OperationalReminderEvent.objects.get()
        self.assertEqual(event.actor_id, self.owner.pk)
        self.assertEqual(event.action, "tomorrow")
        self.client.force_login(self.owner)
        inbox = reverse("api-operational-inbox", kwargs={
            "workspace_id": self.ws.pk})
        self.assertEqual(self.client.get(inbox, {
            "day": "2027-02-08", "scope": "today"
        }).json()["counts"]["today"], 0)
        due = self.client.get(inbox, {
            "day": "2027-02-09", "scope": "today"
        }).json()
        self.assertEqual(due["counts"]["today"], 1)
        self.assertEqual(due["results"][0]["state"], "snoozed")
        self.assertEqual(due["results"][0]["delivery_status"],
                         "not_implemented")

    @patch("reminders.operational_transitions.timezone.localdate",
           return_value=date(2027, 2, 8))
    def test_control_cannot_be_snoozed_to_cutoff_through_http(self, _today):
        self.reminder.control_question = True
        self.reminder.save(update_fields=["control_question"])
        refused = self.action(
            self.owner, action="another_day", days=7)
        self.assertEqual(refused.status_code, 400)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.scheduled_for, date(2027, 2, 8))
        self.assertEqual(OperationalReminderEvent.objects.count(), 0)
        accepted = self.action(
            self.owner, action="another_day", days=6)
        self.assertEqual(accepted.status_code, 200, accepted.content)
        self.assertEqual(accepted.json()["scheduled_for"], "2027-02-14")
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)

    @patch("reminders.operational_transitions.timezone.localdate",
           return_value=date(2027, 2, 14))
    def test_tomorrow_control_on_cutoff_refused(self, _today):
        self.reminder.control_question = True
        self.reminder.save(update_fields=["control_question"])
        result = self.action(self.owner, action="tomorrow")
        self.assertEqual(result.status_code, 400)
        self.assertFalse(OperationalReminderEvent.objects.exists())

    def test_closed_renewal_rejects_action_without_audit(self):
        self.renewal.status = Renewal.Status.CLOSED
        self.renewal.save(update_fields=["status"])
        response = self.action(self.owner)
        self.assertEqual(response.status_code, 409)
        self.assertFalse(OperationalReminderEvent.objects.exists())

    def test_idempotent_http_complete_produces_single_event(self):
        key = uuid.uuid4()
        first = self.action(self.owner, key=key)
        second = self.action(self.owner, key=key)
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)
        self.assertEqual(OperationalReminder.objects.count(), 1)
