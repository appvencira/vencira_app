"""Pruebas del motor persistente A, exclusivamente en DB de tests."""
from datetime import date
from django.test import TestCase
from reminders.models import (
    OperationalReminder, OperationalReminderEvent, Renewal, Workspace,
)
from reminders.operational_reconcile import reconcile_expiry_reminders


class OperationalReconcileTests(TestCase):
    def setUp(self):
        self.workspace = Workspace.objects.create(name="Pruebas programación A")
        self.renewal = Renewal.objects.create(
            workspace=self.workspace, customer_reference="FAKE-001",
            expires_on=date(2027, 3, 15), modality="autos",
        )

    def reconcile(self):
        return reconcile_expiry_reminders(
            self.renewal.pk, as_of=date(2027, 1, 1))

    def test_creates_three_and_preserves_identity_on_retry(self):
        first = self.reconcile()
        self.assertEqual(len(first), 3)
        self.assertEqual([x.scheduled_for for x in first], [
            date(2027, 1, 14), date(2027, 1, 29), date(2027, 2, 8)])
        self.assertEqual(sum(x.control_question for x in first), 1)
        self.assertEqual([x.pk for x in first], [x.pk for x in self.reconcile()])
        self.assertEqual(OperationalReminder.objects.count(), 3)
        self.assertEqual(OperationalReminderEvent.objects.count(), 3)

    def test_expiry_change_cancels_old_and_creates_new_generation(self):
        original = self.reconcile()
        self.renewal.expires_on = date(2027, 4, 15)
        self.renewal.save(update_fields=["expires_on"])
        next_set = self.reconcile()
        self.assertEqual(OperationalReminder.objects.count(), 6)
        self.assertEqual(OperationalReminder.objects.filter(state="cancelled").count(), 3)
        self.assertEqual(OperationalReminder.objects.filter(state="planned").count(), 3)
        self.assertTrue(all(x.generation == 2 for x in next_set))
        self.assertFalse(set(x.pk for x in original) & set(x.pk for x in next_set))

    def test_completed_not_resurrected(self):
        original = self.reconcile()
        first = original[0]
        first.state = OperationalReminder.State.COMPLETED
        first.save(update_fields=["state"])
        again = self.reconcile()
        self.assertEqual(again[0].pk, first.pk)
        self.assertEqual(OperationalReminder.objects.count(), 3)

    def test_close_cancels_only_active(self):
        self.reconcile()
        self.renewal.status = Renewal.Status.CLOSED
        self.renewal.save(update_fields=["status"])
        self.assertEqual(self.reconcile(), ())
        self.assertEqual(OperationalReminder.objects.filter(state="cancelled").count(), 3)

    def test_life_never_schedules(self):
        self.renewal.modality = "vida"
        self.renewal.save(update_fields=["modality"])
        with self.assertRaises(ValueError):
            self.reconcile()
        self.assertFalse(OperationalReminder.objects.exists())

    def test_missing_control_never_schedules(self):
        with self.assertRaises(ValueError):
            reconcile_expiry_reminders(self.renewal.pk,
                as_of=date(2027, 1, 1), days_before=(30, 15))
        self.assertFalse(OperationalReminder.objects.exists())

    def test_late_creation_never_backfills(self):
        with self.assertRaises(ValueError):
            reconcile_expiry_reminders(self.renewal.pk,
                as_of=date(2027, 2, 10))
        self.assertFalse(OperationalReminder.objects.exists())
