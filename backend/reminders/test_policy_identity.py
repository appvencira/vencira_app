"""Regresiones de la ampliación aditiva de ficha de póliza externa."""
from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase

from .audit import make_audit_event
from .models import Renewal, RenewalAuditEvent, Workspace, WorkspaceMember
from .serializers import RenewalSerializer


class PolicyIdentityTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="identity_test", password="test-only-pass-2026!"
        )
        cls.workspace = Workspace.objects.create(name="Test identidad")
        cls.membership = WorkspaceMember.objects.create(
            workspace=cls.workspace, user=cls.user,
            role=WorkspaceMember.Role.OWNER,
        )

    def test_legacy_renewal_keeps_empty_fields(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="LEGACY",
            expires_on=date(2027, 5, 1),
        )
        old.refresh_from_db()
        for field in ("full_name", "nickname", "phone", "email", "policy_number"):
            self.assertEqual(getattr(old, field), "")

    def test_serializer_writes_fields_without_changing_customer_reference(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="LEGACY",
            expires_on=date(2027, 5, 1),
        )
        payload = {
            "full_name": "Persona sintética",
            "nickname": "Prueba",
            "phone": "+34600000000",
            "email": "prueba@example.invalid",
            "policy_number": "POL-DEMO-001",
        }
        serializer = RenewalSerializer(
            old, data=payload, partial=True,
            context={"membership": self.membership},
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        serializer.save()
        old.refresh_from_db()
        self.assertEqual(old.customer_reference, "LEGACY")
        for key, value in payload.items():
            self.assertEqual(getattr(old, key), value)

    def test_invalid_email_rejected(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="LEGACY",
            expires_on=date(2027, 5, 1),
        )
        serializer = RenewalSerializer(
            old, data={"email": "correo-invalido"}, partial=True,
            context={"membership": self.membership},
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("email", serializer.errors)

    def test_audit_never_stores_personal_values(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="LEGACY",
            expires_on=date(2027, 5, 1),
        )
        before = Renewal(
            customer_reference=old.customer_reference, full_name="",
            nickname="", phone="", email="", policy_number="",
            entry=old.entry, modality=old.modality, insurer=old.insurer,
            expires_on=old.expires_on, notice_deadline_on=old.notice_deadline_on,
            status=old.status, assigned_to_id=old.assigned_to_id,
        )
        old.full_name = "Nombre sintético secreto"
        old.phone = "+34600111222"
        old.save(update_fields=["full_name", "phone"])
        event = make_audit_event(renewal=old, actor=self.user, before=before)
        self.assertIsNotNone(event)
        self.assertEqual(
            set(event.changed_fields), {"full_name", "phone"}
        )
        self.assertNotIn("Nombre sintético secreto", str(event.metadata))
        self.assertNotIn("+34600111222", str(event.metadata))
        self.assertEqual(
            RenewalAuditEvent.objects.filter(workspace=self.workspace).count(), 1
        )
