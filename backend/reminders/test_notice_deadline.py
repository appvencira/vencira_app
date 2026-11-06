"""Separación explícita entre vencimiento y preaviso sin envíos ni supuestos legales."""
from datetime import date
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from .candidate_service import refresh_candidates
from .models import ReminderCandidate, ReminderPolicy, Renewal, RenewalAuditEvent, Workspace, WorkspaceMember


class NoticeDeadlineTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.a = Workspace.objects.create(name="A")
        cls.b = Workspace.objects.create(name="B")
        cls.user = get_user_model().objects.create_user(username="demo-preaviso", password="OnlyTests-LongPassword-2026")
        WorkspaceMember.objects.create(
            workspace=cls.a, user=cls.user, role=WorkspaceMember.Role.OWNER
        )
        cls.item = Renewal.objects.create(
            workspace=cls.a,
            customer_reference="CONTRATO-FICTICIO",
            expires_on=date(2027, 5, 1),
            notice_deadline_on=date(2027, 3, 31),
        )
        cls.other = Renewal.objects.create(
            workspace=cls.b,
            customer_reference="OTRO-FICTICIO",
            expires_on=date(2027, 5, 1),
            notice_deadline_on=date(2027, 3, 31),
        )

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(self.user)

    def detail_url(self):
        return reverse("api-renewal-detail", kwargs={
            "workspace_id": self.a.id, "renewal_id": self.item.id,
        })

    def test_read_deadline_separately_and_audit_update(self):
        response = self.client.get(self.detail_url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["expires_on"], "2027-05-01")
        self.assertEqual(response.data["notice_deadline_on"], "2027-03-31")
        result = self.client.patch(self.detail_url(), {"notice_deadline_on": "2027-04-05"}, format="json")
        self.assertEqual(result.status_code, 200)
        self.item.refresh_from_db()
        self.assertEqual(self.item.notice_deadline_on, date(2027, 4, 5))
        event = RenewalAuditEvent.objects.get()
        self.assertEqual(event.changed_fields, ["notice_deadline_on"])
        self.assertEqual(event.metadata["notice_deadline_on"], {"before": "2027-03-31", "after": "2027-04-05"})

    def test_invalid_notice_later_than_contract_expiry(self):
        response = self.client.patch(self.detail_url(), {"notice_deadline_on": "2027-05-02"}, format="json")
        self.assertEqual(response.status_code, 400)
        response = self.client.patch(self.detail_url(), {"expires_on": "2027-02-01"}, format="json")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(RenewalAuditEvent.objects.count(), 0)

    def test_null_deadline_allowed_and_audited(self):
        response = self.client.patch(self.detail_url(), {"notice_deadline_on": None}, format="json")
        self.assertEqual(response.status_code, 200)
        self.item.refresh_from_db()
        self.assertIsNone(self.item.notice_deadline_on)
        self.assertIsNone(RenewalAuditEvent.objects.get().metadata["notice_deadline_on"]["after"])

    def test_preaviso_policy_uses_only_explicit_deadline(self):
        policy = ReminderPolicy.objects.create(
            workspace=self.a, basis=ReminderPolicy.Basis.NOTICE_DEADLINE,
            days_before=10, enabled=True,
        )
        today = date(2027, 3, 20)
        result = refresh_candidates(self.a.id, today=today, horizon_days=15)
        self.assertEqual(result["created"], 1)
        self.assertEqual(ReminderCandidate.objects.get().scheduled_for, date(2027, 3, 21))
        self.assertEqual(ReminderCandidate.objects.get().policy, policy)
        self.assertFalse(ReminderCandidate.objects.filter(renewal=self.other).exists())
        self.item.notice_deadline_on = None
        self.item.save(update_fields=["notice_deadline_on"])
        self.assertEqual(refresh_candidates(self.a.id, today=today, horizon_days=15)["cancelled"], 1)
        self.assertFalse(ReminderCandidate.objects.filter(state="planned").exists())

    def test_legacy_expiry_policy_remains_default_and_no_inferred_notice(self):
        self.item.notice_deadline_on = None
        self.item.save(update_fields=["notice_deadline_on"])
        a = ReminderPolicy.objects.create(workspace=self.a, days_before=10, enabled=True)
        b = ReminderPolicy.objects.create(
            workspace=self.a, basis=ReminderPolicy.Basis.NOTICE_DEADLINE,
            days_before=10, enabled=True,
        )
        self.assertEqual(a.basis, ReminderPolicy.Basis.EXPIRY)
        self.assertEqual(b.basis, ReminderPolicy.Basis.NOTICE_DEADLINE)
        result = refresh_candidates(self.a.id, today=date(2027, 4, 15), horizon_days=30)
        self.assertEqual(result["created"], 1)
        self.assertEqual(ReminderCandidate.objects.get().scheduled_for, date(2027, 4, 21))
        self.assertEqual(ReminderCandidate.objects.get().policy, a)

    def test_change_notice_deadline_reconciles_old_future_candidate(self):
        ReminderPolicy.objects.create(
            workspace=self.a, basis=ReminderPolicy.Basis.NOTICE_DEADLINE,
            days_before=5, enabled=True,
        )
        now = date(2027, 3, 1)
        refresh_candidates(self.a.id, today=now, horizon_days=35)
        self.item.notice_deadline_on = date(2027, 4, 5)
        self.item.save(update_fields=["notice_deadline_on"])
        stats = refresh_candidates(self.a.id, today=now, horizon_days=35)
        self.assertEqual(stats, {"created": 1, "restored": 0, "cancelled": 1})
        self.assertEqual(
            list(ReminderCandidate.objects.filter(state="planned").values_list("scheduled_for", flat=True)),
            [date(2027, 3, 31)],
        )

    def test_contacted_state_still_suppresses_candidates_until_decided(self):
        ReminderPolicy.objects.create(workspace=self.a, days_before=10, enabled=True)
        self.item.status = Renewal.Status.CONTACTED
        self.item.save(update_fields=["status"])
        result = refresh_candidates(self.a.id, today=date(2027, 4, 15), horizon_days=30)
        self.assertEqual(result["created"], 0)

    def test_database_rejects_incoherent_notice_deadline(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                Renewal.objects.create(
                    workspace=self.a, customer_reference="INVALIDO",
                    expires_on=date(2027, 3, 1),
                    notice_deadline_on=date(2027, 4, 1),
                )

    def test_database_rejects_unknown_rule_basis(self):
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                ReminderPolicy.objects.create(
                    workspace=self.a, days_before=7,
                    basis="invalido",
                )
