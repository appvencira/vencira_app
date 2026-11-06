from datetime import date
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import SimpleTestCase, TestCase
from django.urls import reverse
from .models import Renewal, Workspace, WorkspaceMember

class HealthTests(SimpleTestCase):
    def test_health(self):
        response = self.client.get(reverse("health"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        self.assertEqual(response["Cache-Control"], "no-store")

    def test_http_method(self):
        self.assertEqual(self.client.post(reverse("health")).status_code, 405)

class ReadyTests(TestCase):
    def test_database(self):
        response = self.client.get(reverse("ready"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ready"})

class DomainModelTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(username="prueba", password="test-unique-2026-ABC!")
        cls.a = Workspace.objects.create(name="Equipo de prueba A")
        cls.b = Workspace.objects.create(name="Equipo de prueba B")
        cls.renewal_a = Renewal.objects.create(workspace=cls.a, customer_reference="DEMO-A", expires_on=date(2027, 1, 1))
        cls.renewal_b = Renewal.objects.create(workspace=cls.b, customer_reference="DEMO-B", expires_on=date(2027, 2, 1))

    def test_scoped_filter(self):
        self.assertEqual(list(Renewal.objects.filter(workspace=self.a)), [self.renewal_a])
        self.assertEqual(list(Renewal.objects.filter(workspace=self.b)), [self.renewal_b])

    def test_unique_membership(self):
        WorkspaceMember.objects.create(workspace=self.a, user=self.user)
        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                WorkspaceMember.objects.create(workspace=self.a, user=self.user)
