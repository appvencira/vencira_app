"""O3: precise business outcomes, tenant safety, audit and archive lifecycle."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase, APIClient

from .models import (
    Workspace, WorkspaceMember, Renewal, RenewalOutcome, RenewalAuditEvent,
    RenewalFollowUp, ReminderPolicy, ReminderCandidate,
)


class OutcomeTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        user = get_user_model()
        cls.owner = user.objects.create_user(
            username="o3-owner", password="Dev-test-Owner-2026!")
        cls.member = user.objects.create_user(
            username="o3-member", password="Dev-test-Member-2026!")
        cls.foreign = user.objects.create_user(
            username="o3-foreign", password="Dev-test-Foreign-2026!")
        cls.workspace = Workspace.objects.create(name="Outcome demo")
        cls.other_workspace = Workspace.objects.create(name="Other demo")
        WorkspaceMember.objects.create(
            workspace=cls.workspace, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(
            workspace=cls.workspace, user=cls.member, role="member")
        WorkspaceMember.objects.create(
            workspace=cls.other_workspace, user=cls.foreign, role="owner")
        cls.item = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.member,
            customer_reference="O3-SYNTHETIC",
            entry=Renewal.Entry.PROSPECTS,
            status=Renewal.Status.CONTACTED,
            expires_on=date(2028, 2, 29),
            notice_deadline_on=date(2028, 1, 29),
            notes="Anotación ficticia privada",
        )
        cls.other = Renewal.objects.create(
            workspace=cls.other_workspace, assigned_to=cls.foreign,
            customer_reference="FOREIGN",
            expires_on=date(2028, 2, 29),
        )
        cls.policy = ReminderPolicy.objects.create(
            workspace=cls.workspace, basis="expiry",
            days_before=30, enabled=True,
        )

    def url(self, workspace=None, item=None):
        return reverse("api-renewal-outcomes", kwargs={
            "workspace_id": (workspace or self.workspace).pk,
            "renewal_id": (item or self.item).pk,
        })

    def test_won_archives_converts_only_annotation_and_restores_candidate(self):
        self.client.force_authenticate(user=self.member)
        prior_follow = RenewalFollowUp.objects.create(
            renewal=self.item, scheduled_for=date(2028, 2, 10),
            created_by=self.member,
        )
        response = self.client.post(self.url(), {"kind": "won"}, format="json")
        self.assertEqual(response.status_code, 201)
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, "closed")
        self.assertEqual(self.item.archive_outcome, "won")
        self.assertIsNotNone(self.item.archived_at)
        self.assertEqual(self.item.entry, Renewal.Entry.CLIENTS)
        self.assertEqual(RenewalFollowUp.objects.get(pk=prior_follow.pk).state,
                         "cancelled")
        self.assertEqual(RenewalOutcome.objects.filter(
            renewal=self.item, kind="won").count(), 1)
        self.assertNotIn(self.item.pk, [
            x["id"] for x in self.client.get(self._renewals()).data["results"]
        ])
        archive = self.client.get(self._renewals() + "?status=closed")
        self.assertEqual(archive.status_code, 200)
        self.assertEqual(archive.data["results"][0]["archive_outcome"], "won")

        self.assertEqual(self.client.post(
            self.url(), {"kind": "discarded"}, format="json").status_code, 409)
        restored = self.client.post(
            self.url(), {"kind": "restored"}, format="json")
        self.assertEqual(restored.status_code, 201)
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, "pending")
        self.assertIsNone(self.item.archived_at)
        self.assertEqual(self.item.entry, Renewal.Entry.PROSPECTS)
        self.assertEqual(RenewalOutcome.objects.filter(
            renewal=self.item, kind="restored").count(), 1)
        self.assertNotIn("O3-SYNTHETIC", str(self.client.get(
            self.url()).data))  # only event enums/dates, no PII

    def _renewals(self):
        return reverse("api-renewals", kwargs={
            "workspace_id": self.workspace.pk,
        })

    def test_declined_next_year_leap_and_reminder_candidates_reset(self):
        self.client.force_authenticate(user=self.member)
        old_candidate = ReminderCandidate.objects.create(
            renewal=self.item, policy=self.policy,
            scheduled_for=date(2028, 1, 30),
        )
        response = self.client.post(
            self.url(), {"kind": "declined"}, format="json")
        self.assertEqual(response.status_code, 201)
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, "pending")
        self.assertEqual(self.item.expires_on, date(2029, 2, 28))
        self.assertEqual(self.item.notice_deadline_on, date(2029, 1, 29))
        self.assertEqual(self.item.notes, "Anotación ficticia privada")
        self.assertEqual(ReminderCandidate.objects.get(
            pk=old_candidate.pk).state, "cancelled")
        next_candidate = ReminderCandidate.objects.get(
            renewal=self.item, policy=self.policy,
            scheduled_for=date(2029, 1, 29))
        self.assertEqual(next_candidate.state, "planned")
        self.assertIsNone(self.item.archived_at)
        history = self.client.get(self.url())
        self.assertEqual(history.status_code, 200)
        self.assertEqual(history.data["results"][0]["kind"], "declined")
        self.assertEqual(history.data["results"][0]["previous_expiry"],
                         "2028-02-29")
        self.assertEqual(history.data["results"][0]["new_expiry"],
                         "2029-02-28")

    def test_undecided_schedules_o2_once_without_archiving(self):
        self.client.force_authenticate(user=self.member)
        first = self.client.post(self.url(), {
            "kind": "undecided", "scheduled_for": "2027-11-15",
        }, format="json")
        self.assertEqual(first.status_code, 201)
        next_time = self.client.post(self.url(), {
            "kind": "undecided", "scheduled_for": "2027-11-20",
        }, format="json")
        self.assertEqual(next_time.status_code, 201)
        self.assertEqual(RenewalFollowUp.objects.filter(
            renewal=self.item, state="planned").count(), 1)
        self.assertEqual(RenewalFollowUp.objects.filter(
            renewal=self.item, state="cancelled").count(), 1)
        self.assertEqual(RenewalFollowUp.objects.get(
            renewal=self.item, state="planned").scheduled_for,
            date(2027, 11, 20))
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, "contacted")
        self.assertIsNone(self.item.archived_at)

    def test_discard_archive_restorable_and_no_agenda(self):
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.post(self.url(), {
            "kind": "discarded"}, format="json").status_code, 201)
        self.item.refresh_from_db()
        self.assertEqual(self.item.archive_outcome, "discarded")
        self.assertEqual(self.item.entry, Renewal.Entry.PROSPECTS)
        self.assertEqual(self.client.post(self.url(), {
            "kind": "restored"}, format="json").status_code, 201)
        self.item.refresh_from_db()
        self.assertEqual(self.item.status, "pending")
        self.assertEqual(self.item.entry, Renewal.Entry.PROSPECTS)

    def test_strict_payload_permissions_and_csrf(self):
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.get(
            self.url(workspace=self.other_workspace, item=self.other)).status_code, 404)
        for payload in [
            {"kind": "won", "workspace": str(self.other_workspace.pk)},
            {"kind": "undecided"},
            {"kind": "undecided", "scheduled_for": "2027-02-30"},
            {"kind": "unknown"},
            {"kind": "restored"},
        ]:
            with self.subTest(payload=payload):
                code = self.client.post(self.url(), payload, format="json").status_code
                self.assertIn(code, (400, 409))
        self.client.force_authenticate(user=self.foreign)
        self.assertEqual(self.client.post(self.url(), {
            "kind": "won"}, format="json").status_code, 404)
        self.client.force_authenticate(user=None)
        client = APIClient(enforce_csrf_checks=True)
        client.force_login(self.owner)
        self.assertEqual(client.post(
            self.url(), {"kind": "won"}, format="json").status_code, 403)

    def test_no_personal_data_in_audit_metadata(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url(), {
            "kind": "undecided", "scheduled_for": "2027-11-15",
        }, format="json")
        event = RenewalAuditEvent.objects.filter(
            renewal=self.item, changed_fields__contains=["outcome"]).first()
        self.assertIsNotNone(event)
        self.assertNotIn("O3-SYNTHETIC", str(event.metadata))
        self.assertNotIn("Anotación ficticia privada", str(event.metadata))
