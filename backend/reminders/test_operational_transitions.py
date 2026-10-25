"""Pruebas de cambios explícitos de estado de avisos en DB temporal."""
import uuid
from datetime import date, datetime
from unittest.mock import patch
from django.test import TestCase
from reminders.models import OperationalReminder, OperationalReminderEvent, Renewal, Workspace
from reminders.operational_transitions import transition_reminder, ReminderConflict


class OperationalTransitionTests(TestCase):
    def setUp(self):
        self.workspace = Workspace.objects.create(name="Temporal")
        self.renewal = Renewal.objects.create(
            workspace=self.workspace, customer_reference="FICTICIO",
            expires_on=date(2027, 3, 15))
        self.reminder = OperationalReminder.objects.create(
            renewal=self.renewal, kind="expiry", days_before=35,
            scheduled_for=date(2027, 2, 8),
            original_scheduled_for=date(2027, 2, 8),
            source_key="expiry:35", reason="Aviso",
            control_question=True)

    def act(self, action, *, key=None, state="planned", day=date(2027, 2, 8),
            days_later=None, now=date(2027, 2, 8)):
        return transition_reminder(
            renewal_id=self.renewal.pk, reminder_id=self.reminder.pk,
            action=action, expected_state=state, expected_day=day,
            idempotency_key=key or uuid.uuid4(), actor=None,
            days_later=days_later, as_of=now)

    def test_complete_is_idempotent(self):
        key = uuid.uuid4()
        self.act("complete", key=key)
        self.act("complete", key=key)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.state, "completed")
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)

    def test_tomorrow_replay_next_day_is_idempotent(self):
        key = uuid.uuid4()
        self.act("tomorrow", key=key)
        with patch("reminders.operational_transitions.timezone.localtime",
                   return_value=datetime(2027, 2, 8, 12, 0)):
            self.act("tomorrow", key=key, now=date(2027, 2, 9))
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.scheduled_for, date(2027, 2, 9))

    def test_replay_key_with_different_days_conflicts(self):
        self.reminder.control_question = False
        self.reminder.save(update_fields=["control_question"])
        key = uuid.uuid4()
        self.act("another_day", key=key, days_later=3)
        with patch("reminders.operational_transitions.timezone.localtime",
                   return_value=datetime(2027, 2, 8, 12, 0)):
            with self.assertRaises(ReminderConflict):
                self.act("another_day", key=key, days_later=4)
        self.assertEqual(OperationalReminderEvent.objects.count(), 1)

    def test_tomorrow_and_stale_cas(self):
        self.act("tomorrow")
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.state, "snoozed")
        self.assertEqual(self.reminder.scheduled_for, date(2027, 2, 9))
        with self.assertRaises(ReminderConflict):
            self.act("complete")

    def test_control_cannot_be_postponed_past_cutoff(self):
        with self.assertRaises(ValueError):
            self.act("another_day", days_later=8)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.state, "planned")
        self.assertEqual(OperationalReminderEvent.objects.count(), 0)

    def test_control_can_be_postponed_to_cutoff(self):
        self.act("another_day", days_later=7)
        self.reminder.refresh_from_db()
        self.assertEqual(self.reminder.scheduled_for, date(2027, 2, 15))

    def test_unauthorized_actions_must_be_rejected_upstream(self):
        # This domain service is not an authorization boundary.
        # An authenticated API MUST scope renewal_id and actor before invoking.
        with self.assertRaises(ValueError):
            self.act("tomorrow", days_later=1)
        with self.assertRaises(ValueError):
            self.act("another_day", days_later=1)
