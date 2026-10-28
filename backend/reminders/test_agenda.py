"""Contrato mínimo de agenda diaria: eventos previstos, permisos y paginación."""
from datetime import date

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import ReminderCandidate, ReminderPolicy, Renewal, Workspace, WorkspaceMember


class DayAgendaTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        user = get_user_model()
        cls.owner = user.objects.create_user(username="agenda-owner", password="test-only-Strong!1")
        cls.alice = user.objects.create_user(username="agenda-alice", password="test-only-Strong!2")
        cls.bob = user.objects.create_user(username="agenda-bob", password="test-only-Strong!3")
        cls.foreign = user.objects.create_user(username="agenda-foreign", password="test-only-Strong!4")
        cls.workspace = Workspace.objects.create(name="Agenda - pruebas")
        cls.foreign_workspace = Workspace.objects.create(name="Agenda - ajena")
        for account, role in (
            (cls.owner, WorkspaceMember.Role.OWNER),
            (cls.alice, WorkspaceMember.Role.MEMBER),
            (cls.bob, WorkspaceMember.Role.MEMBER),
        ):
            WorkspaceMember.objects.create(
                workspace=cls.workspace, user=account, role=role
            )
        WorkspaceMember.objects.create(
            workspace=cls.foreign_workspace, user=cls.foreign,
            role=WorkspaceMember.Role.OWNER,
        )
        cls.day = date(2027, 3, 31)
        cls.alice_expiry = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.alice,
            customer_reference="ALICE-VENCE", expires_on=cls.day,
        )
        cls.bob_expiry = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.bob,
            customer_reference="BOB-VENCE", expires_on=cls.day,
        )
        cls.alice_reminder = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.alice,
            customer_reference="ALICE-AVISO", expires_on=date(2027, 5, 1),
        )
        cls.unassigned = Renewal.objects.create(
            workspace=cls.workspace,
            customer_reference="PENDIENTE-DE-ASIGNAR", expires_on=cls.day,
        )
        cls.closed = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.alice,
            customer_reference="CERRADA", expires_on=cls.day,
            status=Renewal.Status.CLOSED,
        )
        cls.foreign_item = Renewal.objects.create(
            workspace=cls.foreign_workspace, assigned_to=cls.foreign,
            customer_reference="OTRA-ORGANIZACION", expires_on=cls.day,
        )
        cls.policy = ReminderPolicy.objects.create(
            workspace=cls.workspace, enabled=True, days_before=31,
        )
        cls.candidate = ReminderCandidate.objects.create(
            renewal=cls.alice_reminder,
            policy=cls.policy,
            scheduled_for=cls.day,
            state=ReminderCandidate.State.PLANNED,
        )

    def url(self, workspace=None, day="2027-03-31"):
        route = reverse(
            "api-agenda-day",
            kwargs={"workspace_id": (workspace or self.workspace).id},
        )
        return route + f"?day={day}"

    def test_member_only_sees_expiry_and_reminder_assigned_to_self(self):
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["day"], "2027-03-31")
        self.assertEqual(response.data["count"], 2)
        results = {
            row["renewal"]["customer_reference"]: row
            for row in response.data["results"]
        }
        self.assertEqual(set(results), {"ALICE-VENCE", "ALICE-AVISO"})
        self.assertEqual(results["ALICE-VENCE"]["events"], [{"kind": "expiry"}])
        self.assertEqual(results["ALICE-AVISO"]["events"], [{
            "kind": "reminder",
            "candidate_id": self.candidate.id,
            "basis": ReminderPolicy.Basis.EXPIRY,
        }])
        self.assertNotIn("BOB-VENCE", str(response.data))
        self.assertNotIn("OTRA-ORGANIZACION", str(response.data))

    def test_owner_sees_all_active_team_entries_and_unassigned(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 4)
        refs = {
            row["renewal"]["customer_reference"]
            for row in response.data["results"]
        }
        self.assertEqual(refs, {
            "ALICE-VENCE", "BOB-VENCE", "ALICE-AVISO", "PENDIENTE-DE-ASIGNAR",
        })
        self.assertNotIn("CERRADA", refs)

    def test_invalid_day_and_wrong_workspace_denied(self):
        self.client.force_authenticate(user=self.alice)
        for value in ("", "2027-02-30", "31/03/2027", "2027-03-31T12:00:00"):
            with self.subTest(day=value):
                self.assertEqual(self.client.get(self.url(day=value)).status_code, 400)
        self.assertEqual(self.client.get(
            self.url(workspace=self.foreign_workspace)
        ).status_code, 404)
        self.client.force_authenticate(user=self.foreign)
        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))

    def test_pagination_is_bounded_and_preserves_selected_day(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url() + "&page_size=1")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["day"], "2027-03-31")
        self.assertEqual(response.data["count"], 4)
        self.assertEqual(len(response.data["results"]), 1)
        self.assertIsNotNone(response.data["next"])

    def test_contractual_notice_is_visible_without_reminder_policy(self):
        """Un límite explícito figura en su día aunque no se programe aviso."""
        renewal = Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.alice,
            customer_reference="PREAVISO-SIN-RECORDATORIO",
            expires_on=date(2027, 4, 2),
            notice_deadline_on=self.day,
        )
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 3)
        rows = {
            row["renewal"]["customer_reference"]: row
            for row in response.data["results"]
        }
        self.assertEqual(
            rows["PREAVISO-SIN-RECORDATORIO"]["events"],
            [{"kind": "notice_deadline"}],
        )
        self.assertEqual(
            rows["PREAVISO-SIN-RECORDATORIO"]["renewal"]["id"], str(renewal.id)
        )
        self.assertEqual(
            rows["PREAVISO-SIN-RECORDATORIO"]["renewal"]["notice_deadline_on"],
            "2027-03-31",
        )
        self.assertNotIn("BOB-VENCE", rows)

    def test_same_day_expiry_and_notice_are_one_renewal_with_two_events(self):
        Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.alice,
            customer_reference="AMBAS-FECHAS-IGUALES",
            expires_on=self.day,
            notice_deadline_on=self.day,
        )
        self.client.force_authenticate(user=self.alice)
        response = self.client.get(self.url())
        self.assertEqual(response.data["count"], 3)
        matching = [
            row for row in response.data["results"]
            if row["renewal"]["customer_reference"] == "AMBAS-FECHAS-IGUALES"
        ]
        self.assertEqual(len(matching), 1)
        self.assertEqual(matching[0]["events"], [
            {"kind": "expiry"}, {"kind": "notice_deadline"},
        ])

    def test_notice_respects_closed_status_and_workspace_assignment(self):
        Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.bob,
            customer_reference="PREAVISO-DE-BOB",
            expires_on=date(2027, 4, 2), notice_deadline_on=self.day,
        )
        Renewal.objects.create(
            workspace=self.foreign_workspace, assigned_to=self.foreign,
            customer_reference="PREAVISO-AJENO",
            expires_on=date(2027, 4, 2), notice_deadline_on=self.day,
        )
        Renewal.objects.create(
            workspace=self.workspace, assigned_to=self.alice,
            customer_reference="PREAVISO-CERRADO",
            expires_on=date(2027, 4, 2), notice_deadline_on=self.day,
            status=Renewal.Status.CLOSED,
        )
        self.client.force_authenticate(user=self.alice)
        own = self.client.get(self.url())
        self.assertEqual(own.data["count"], 2)
        self.assertNotIn("PREAVISO-DE-BOB", str(own.data))
        self.assertNotIn("PREAVISO-AJENO", str(own.data))
        self.assertNotIn("PREAVISO-CERRADO", str(own.data))
        self.client.force_authenticate(user=self.owner)
        owner = self.client.get(self.url())
        self.assertEqual(owner.data["count"], 5)
        self.assertIn("PREAVISO-DE-BOB", str(owner.data))
        self.assertNotIn("PREAVISO-AJENO", str(owner.data))
        self.assertNotIn("PREAVISO-CERRADO", str(owner.data))

    def test_disabled_or_cancelled_candidates_not_reported(self):
        self.client.force_authenticate(user=self.alice)
        self.candidate.state = ReminderCandidate.State.CANCELLED
        self.candidate.save(update_fields=["state"])
        response = self.client.get(self.url())
        self.assertEqual(response.data["count"], 1)
        self.candidate.state = ReminderCandidate.State.PLANNED
        self.candidate.save(update_fields=["state"])
        self.policy.enabled = False
        self.policy.save(update_fields=["enabled"])
        response = self.client.get(self.url())
        self.assertEqual(response.data["count"], 1)
