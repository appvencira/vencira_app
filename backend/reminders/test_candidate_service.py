from datetime import date, timedelta
from django.core.management import call_command
from django.db import IntegrityError, transaction
from django.test import TestCase

from .candidate_service import refresh_candidates
from .models import ReminderCandidate, ReminderPolicy, Renewal, Workspace


class CandidateTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.a = Workspace.objects.create(name="Entidad de prueba A")
        cls.b = Workspace.objects.create(name="Entidad de prueba B")
        cls.policy_a = ReminderPolicy.objects.create(workspace=cls.a, days_before=10)
        cls.renewal_a = Renewal.objects.create(
            workspace=cls.a, expires_on=date(2027, 2, 20),
            customer_reference="CASO-DEMO-A",
        )
        cls.renewal_b = Renewal.objects.create(
            workspace=cls.b, expires_on=date(2027, 2, 20),
            customer_reference="CASO-DEMO-B",
        )

    def test_rules_disabled_by_default(self):
        self.assertFalse(self.policy_a.enabled)
        result = refresh_candidates(self.a.pk, today=date(2027, 2, 1))
        self.assertEqual(result["created"], 0)
        self.assertFalse(ReminderCandidate.objects.exists())

    def test_repeated_generation_is_idempotent(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        day = date(2027, 2, 1)
        self.assertEqual(refresh_candidates(self.a.pk, today=day)["created"], 1)
        self.assertEqual(refresh_candidates(self.a.pk, today=day)["created"], 0)
        item = ReminderCandidate.objects.get()
        self.assertEqual(item.scheduled_for, date(2027, 2, 10))
        self.assertEqual(item.state, ReminderCandidate.State.PLANNED)
        self.assertEqual(item.renewal_id, self.renewal_a.pk)
        self.assertNotEqual(item.renewal_id, self.renewal_b.pk)

    def test_expiration_change_cancels_obsolete_and_prepares_new(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        day = date(2027, 2, 1)
        refresh_candidates(self.a.pk, today=day)
        self.renewal_a.expires_on = date(2027, 2, 25)
        self.renewal_a.save(update_fields=["expires_on"])
        result = refresh_candidates(self.a.pk, today=day)
        self.assertEqual(result, {"created": 1, "restored": 0, "cancelled": 1})
        self.assertEqual(ReminderCandidate.objects.filter(state="planned").count(), 1)
        self.assertEqual(ReminderCandidate.objects.filter(state="cancelled").count(), 1)

    def test_rule_deactivation_cancels_and_reactivation_restores(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        day = date(2027, 2, 1)
        refresh_candidates(self.a.pk, today=day)
        self.policy_a.enabled = False
        self.policy_a.save(update_fields=["enabled"])
        self.assertEqual(refresh_candidates(self.a.pk, today=day)["cancelled"], 1)
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        result = refresh_candidates(self.a.pk, today=day)
        self.assertEqual(result, {"created": 0, "restored": 1, "cancelled": 0})

    def test_closed_renewal_cancels_planned(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        day = date(2027, 2, 1)
        refresh_candidates(self.a.pk, today=day)
        self.renewal_a.status = Renewal.Status.CLOSED
        self.renewal_a.save(update_fields=["status"])
        self.assertEqual(refresh_candidates(self.a.pk, today=day)["cancelled"], 1)

    def test_workspace_data_never_crosses(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        refresh_candidates(self.a.pk, today=date(2027, 2, 1))
        self.assertFalse(ReminderCandidate.objects.filter(renewal__workspace=self.b).exists())

    def test_policy_unique_by_workspace_and_days(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                ReminderPolicy.objects.create(workspace=self.a, days_before=10)

    def test_command_creates_no_delivery(self):
        self.policy_a.enabled = True
        self.policy_a.save(update_fields=["enabled"])
        from io import StringIO
        out = StringIO()
        call_command(
            "prepare_reminder_candidates",
            workspace=str(self.a.pk),
            horizon_days=30,
            stdout=out,
        )
        # La fecha real puede quedar fuera de 2027-02-20: el comando
        # solo debe describir candidatos, no enviar correos.
        self.assertIn("sin envíos", out.getvalue())
