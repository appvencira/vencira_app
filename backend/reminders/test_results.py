"""O7: estadísticas §11 — permisos, periodos civiles y eventos históricos."""
from datetime import date, datetime
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APITestCase

from .models import Renewal, RenewalOutcome, Workspace, WorkspaceMember


class ResultsSummaryTests(APITestCase):
    @classmethod
    def setUpTestData(cls):
        u = get_user_model()
        cls.owner = u.objects.create_user(username="results-owner", password="O7-test-1!")
        cls.member = u.objects.create_user(username="results-member", password="O7-test-2!")
        cls.stranger = u.objects.create_user(username="results-other", password="O7-test-3!")
        cls.ws = Workspace.objects.create(name="Resultados DEMO A")
        cls.other_ws = Workspace.objects.create(name="Resultados DEMO B")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.owner, role="owner")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.member, role="member")
        WorkspaceMember.objects.create(workspace=cls.other_ws, user=cls.stranger, role="owner")

        def renewal(ws, owner, status, expires):
            return Renewal.objects.create(
                workspace=ws, assigned_to=owner, status=status,
                customer_reference="FICTICIO", expires_on=expires,
            )
        cls.pending_a = renewal(cls.ws, cls.member, "pending", date(2027, 3, 31))
        cls.pending_b = renewal(cls.ws, cls.owner, "contacted", date(2027, 3, 1))
        cls.closed = renewal(cls.ws, cls.member, "closed", date(2027, 3, 15))
        cls.april = renewal(cls.ws, cls.member, "pending", date(2027, 4, 1))
        cls.foreign = renewal(cls.other_ws, cls.stranger, "pending", date(2027, 3, 31))

        tz = ZoneInfo("Europe/Madrid")
        # En marzo de 2027 cambia el horario de invierno a verano.
        for item, kind, moment in (
            (cls.closed, "won", datetime(2027, 3, 1, 0, 0, tzinfo=tz)),
            (cls.closed, "discarded", datetime(2027, 3, 31, 23, 59, tzinfo=tz)),
            (cls.pending_a, "declined", datetime(2027, 3, 15, 10, 0, tzinfo=tz)),
            (cls.closed, "restored", datetime(2027, 3, 17, 10, 0, tzinfo=tz)),
            (cls.closed, "undecided", datetime(2027, 3, 19, 10, 0, tzinfo=tz)),
            (cls.closed, "won", datetime(2027, 4, 1, 0, 0, tzinfo=tz)),
            (cls.foreign, "won", datetime(2027, 3, 12, 10, 0, tzinfo=tz)),
        ):
            event = RenewalOutcome.objects.create(
                renewal=item, actor=cls.owner if ws_check(item, cls.ws) else cls.stranger,
                kind=kind,
            )
            RenewalOutcome.objects.filter(pk=event.pk).update(created_at=moment)

    def url(self, ws=None):
        return reverse("api-results-summary", kwargs={
            "workspace_id": (ws or self.ws).pk,
        })

    def test_month_counts_events_not_latest_state_or_cross_tenant(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(self.url(), {"period":"month", "year":"2027", "month":"3"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {
            "period": "month", "from": "2027-03-01",
            "to_exclusive": "2027-04-01", "won": 1, "declined": 1,
            "discarded": 1, "pending": 2,
        })
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertNotIn("FICTICIO", str(response.data))

    def test_quarter_and_year_are_strict_and_local(self):
        self.client.force_authenticate(user=self.owner)
        q = self.client.get(self.url(), {"period":"quarter","year":"2027","quarter":"1"})
        self.assertEqual(q.status_code, 200)
        self.assertEqual(q.data["won"], 1)
        self.assertEqual(q.data["pending"], 2)
        y = self.client.get(self.url(), {"period":"year","year":"2027"})
        self.assertEqual(y.status_code, 200)
        self.assertEqual(y.data["won"], 2)
        self.assertEqual(y.data["pending"], 3)

    def test_reject_invalid_duplicate_and_extra_params(self):
        self.client.force_authenticate(user=self.owner)
        for params in (
            {"period": "month", "year":"2027"},
            {"period": "quarter", "year":"2027", "quarter":"5"},
            {"period": "month", "year":"2027", "month":"03"},
            {"period": "year", "year":"2027", "month":"3"},
            {"period": "year", "year":"2027", "unknown":"1"},
            {"period": "year", "year":"20270"},
            {"period": "year", "year":"1999"},
            {"period": "month", "year":"2027", "month":["3","4"]},
        ):
            with self.subTest(params=params):
                self.assertEqual(self.client.get(self.url(), params).status_code, 400)

    def test_member_forbidden_nonmember_404_anonymous_and_read_only(self):
        self.client.force_authenticate(user=self.member)
        self.assertEqual(self.client.get(self.url(), {"period":"year","year":"2027"}).status_code,403)
        self.client.force_authenticate(user=self.stranger)
        self.assertEqual(self.client.get(self.url(), {"period":"year","year":"2027"}).status_code,404)
        self.client.force_authenticate(user=self.owner)
        self.assertEqual(self.client.get(self.url(self.other_ws), {"period":"year","year":"2027"}).status_code,404)
        self.assertEqual(self.client.post(self.url(), {"period":"year","year":"2027"}).status_code,405)
        self.client.force_authenticate(user=None)
        self.assertIn(self.client.get(self.url(), {"period":"year","year":"2027"}).status_code,(401,403))


def ws_check(item, ws):
    return item.workspace_id == ws.id
