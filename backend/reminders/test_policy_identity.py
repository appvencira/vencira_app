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

    def test_api_search_stays_in_workspace(self):
        from django.urls import reverse

        other = Workspace.objects.create(name="Otra cuenta")
        Renewal.objects.create(
            workspace=other, customer_reference="OTHER",
            full_name="Nombre Solo Otra Cuenta",
            expires_on=date(2027, 6, 1),
        )
        ours = Renewal.objects.create(
            workspace=self.workspace, customer_reference="OUR",
            full_name="Nombre Prueba Local", nickname="Alias Unico",
            policy_number="POL-ABC-789",
            expires_on=date(2027, 6, 2), assigned_to=self.user,
        )
        self.client.force_login(self.user)
        url = reverse("api-renewals", kwargs={"workspace_id": self.workspace.pk})
        for query in ("Nombre Prueba", "Alias Unico", "POL-ABC-789"):
            response = self.client.get(url, {"q": query})
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["count"], 1)
            self.assertEqual(response.json()["results"][0]["id"], str(ours.pk))
        response = self.client.get(url, {"q": "Nombre Solo Otra Cuenta"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["count"], 0)

    def test_api_rejects_cross_workspace_detail(self):
        from django.urls import reverse

        other = Workspace.objects.create(name="Cuenta ajena")
        victim = Renewal.objects.create(
            workspace=other, customer_reference="HIDDEN",
            full_name="No divulgar", expires_on=date(2027, 7, 1),
        )
        self.client.force_login(self.user)
        url = reverse(
            "api-renewal-detail",
            kwargs={"workspace_id": self.workspace.pk, "renewal_id": victim.pk},
        )
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(
            self.client.patch(url, data={"full_name": "Ataque"},
                              content_type="application/json").status_code,
            404,
        )

    def test_notes_are_saved_and_audited_without_content(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="DEMO",
            expires_on=date(2027, 5, 1),
        )
        before = Renewal(
            customer_reference=old.customer_reference,
            full_name=old.full_name, nickname=old.nickname,
            phone=old.phone, email=old.email,
            policy_number=old.policy_number, notes=old.notes,
            entry=old.entry, modality=old.modality, insurer=old.insurer,
            expires_on=old.expires_on,
            notice_deadline_on=old.notice_deadline_on,
            status=old.status, assigned_to_id=old.assigned_to_id,
        )
        serializer = RenewalSerializer(
            old, data={"notes": "Solo notas sintéticas"},
            partial=True, context={"membership": self.membership},
        )
        self.assertTrue(serializer.is_valid(), serializer.errors)
        updated = serializer.save()
        event = make_audit_event(renewal=updated, actor=self.user, before=before)
        self.assertIn("notes", event.changed_fields)
        self.assertNotIn("Solo notas sintéticas", str(event.metadata))
        old.refresh_from_db()
        self.assertEqual(old.notes, "Solo notas sintéticas")

    def test_notes_length_is_limited(self):
        old = Renewal.objects.create(
            workspace=self.workspace, customer_reference="DEMO",
            expires_on=date(2027, 5, 1),
        )
        serializer = RenewalSerializer(
            old, data={"notes": "x" * 4001},
            partial=True, context={"membership": self.membership},
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("notes", serializer.errors)
