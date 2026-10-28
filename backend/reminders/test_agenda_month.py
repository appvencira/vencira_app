"""Agregado mensual: días/estados, fechas civiles, duplicados y permisos."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import ReminderCandidate, ReminderPolicy, Renewal, RenewalFollowUp, Workspace, WorkspaceMember


class MonthAgendaTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model()
        cls.owner = users.objects.create_user(username="month-owner", password="test-month-2026-1!")
        cls.alice = users.objects.create_user(username="month-alice", password="test-month-2026-2!")
        cls.bob = users.objects.create_user(username="month-bob", password="test-month-2026-3!")
        cls.other = users.objects.create_user(username="month-other", password="test-month-2026-4!")
        cls.ws = Workspace.objects.create(name="MES-PRUEBA")
        cls.other_ws = Workspace.objects.create(name="MES-AJENO")
        for user, role in (
            (cls.owner, WorkspaceMember.Role.OWNER),
            (cls.alice, WorkspaceMember.Role.MEMBER),
            (cls.bob, WorkspaceMember.Role.MEMBER),
        ):
            WorkspaceMember.objects.create(workspace=cls.ws, user=user, role=role)
        WorkspaceMember.objects.create(
            workspace=cls.other_ws, user=cls.other, role=WorkspaceMember.Role.OWNER
        )
        cls.a = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.alice,
            customer_reference="ALICE-PENDIENTE",
            expires_on=date(2027, 3, 31), notice_deadline_on=date(2027, 3, 27),
        )
        Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.alice,
            customer_reference="ALICE-CONTACTADO", status=Renewal.Status.CONTACTED,
            expires_on=date(2027, 3, 31),
        )
        Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.bob,
            customer_reference="BOB-PENDIENTE", expires_on=date(2027, 3, 31),
        )
        Renewal.objects.create(
            workspace=cls.ws, customer_reference="SIN-ASIGNAR",
            expires_on=date(2027, 3, 31),
        )
        Renewal.objects.create(
            workspace=cls.other_ws, assigned_to=cls.other,
            customer_reference="AJENO", expires_on=date(2027, 3, 31),
        )
        Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.alice,
            customer_reference="CERRADO", status=Renewal.Status.CLOSED,
            expires_on=date(2027, 3, 31), notice_deadline_on=date(2027, 3, 27),
        )
        Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.alice,
            customer_reference="ABRIL", expires_on=date(2027, 4, 1),
        )
        cls.p1 = ReminderPolicy.objects.create(
            workspace=cls.ws, basis="expiry", days_before=1, enabled=True,
        )
        cls.p2 = ReminderPolicy.objects.create(
            workspace=cls.ws, basis="expiry", days_before=2, enabled=True,
        )
        cls.disabled = ReminderPolicy.objects.create(
            workspace=cls.ws, basis="expiry", days_before=3, enabled=False,
        )
        for policy, day, state in (
            (cls.p1, date(2027, 3, 15), ReminderCandidate.State.PLANNED),
            (cls.p2, date(2027, 3, 15), ReminderCandidate.State.PLANNED),
            (cls.disabled, date(2027, 3, 16), ReminderCandidate.State.PLANNED),
            (cls.p1, date(2027, 3, 17), ReminderCandidate.State.CANCELLED),
        ):
            ReminderCandidate.objects.create(
                renewal=cls.a, policy=policy, scheduled_for=day, state=state,
            )

    def url(self, workspace=None, month="2027-03"):
        return reverse(
            "api-agenda-month",
            kwargs={"workspace_id": (workspace or self.ws).id},
        ) + f"?month={month}"

    def test_member_counts_contractual_dates_reminders_and_contacted(self):
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(response.data["month"], "2027-03")
        days = {row["day"]: row for row in response.data["days"]}
        self.assertEqual(set(days), {"2027-03-15", "2027-03-27", "2027-03-31"})
        self.assertEqual(days["2027-03-15"]["reminder"], {"pending": 1, "contacted": 0})
        self.assertEqual(days["2027-03-27"]["notice_deadline"], {"pending": 1, "contacted": 0})
        self.assertEqual(days["2027-03-31"]["expiry"], {"pending": 1, "contacted": 1})
        self.assertNotIn("AJENO", str(response.data))
        self.assertNotIn("ALICE-PENDIENTE", str(response.data))
        self.assertNotIn("2027-04-01", days)

    def test_owner_sees_team_and_unassigned_not_other_workspace(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url())
        days = {row["day"]: row for row in response.data["days"]}
        self.assertEqual(days["2027-03-31"]["expiry"], {"pending": 3, "contacted": 1})
        self.assertEqual(len(days), 3)

    def test_member_bob_cannot_infer_alice_counts(self):
        self.client.force_authenticate(user=self.bob)
        response = self.client.get(self.url())
        self.assertEqual(response.data["days"], [{
            "day": "2027-03-31",
            "expiry": {"pending": 1, "contacted": 0},
            "notice_deadline": {"pending": 0, "contacted": 0},
            "reminder": {"pending": 0, "contacted": 0},
            "follow_up": {"pending": 0, "contacted": 0},
        }])

    def test_follow_up_counts_only_for_assigned_member(self):
        # A manual follow-up must not expose Alice's activity to Bob within
        # the same organization, even as aggregate day counts.
        RenewalFollowUp.objects.create(
            renewal=self.a, scheduled_for=date(2027, 3, 22),
            created_by=self.alice,
        )
        bob_item = Renewal.objects.get(
            workspace=self.ws, customer_reference="BOB-PENDIENTE",
        )
        RenewalFollowUp.objects.create(
            renewal=bob_item, scheduled_for=date(2027, 3, 23),
            created_by=self.bob,
        )

        self.client.force_authenticate(user=self.bob)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        bob_days = {entry["day"]: entry for entry in response.data["days"]}
        self.assertNotIn("2027-03-22", bob_days)
        self.assertEqual(bob_days["2027-03-23"]["follow_up"],
                         {"pending": 1, "contacted": 0})

        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url())
        alice_days = {entry["day"]: entry for entry in response.data["days"]}
        self.assertNotIn("2027-03-23", alice_days)
        self.assertEqual(alice_days["2027-03-22"]["follow_up"],
                         {"pending": 1, "contacted": 0})

    def test_anonymous_foreign_workspace_and_invalid_month_denied(self):
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
        self.client.force_authenticate(user=self.alice)
        self.assertEqual(self.client.get(self.url(workspace=self.other_ws)).status_code, 404)
        for invalid in ("", "2027-3", "2027-13", "2027-02-01", "1999-12", "2101-01", "2027-03&day=x"):
            with self.subTest(invalid=invalid):
                self.assertEqual(self.client.get(self.url(month=invalid)).status_code, 400)
        self.assertEqual(self.client.post(self.url()).status_code, 405)

    def test_empty_month_and_boundary(self):
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url(month="2027-04"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual([d["day"] for d in response.data["days"]], ["2027-04-01"])
        response = self.client.get(self.url(month="2027-02"))
        self.assertEqual(response.data["days"], [])
