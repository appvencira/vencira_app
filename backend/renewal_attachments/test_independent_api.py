"""Tenant-scoped read-only API tests in isolated split rehearsal only."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from reminders.models import Renewal, Workspace, WorkspaceMember
from .models import RenewalAttachment


class IndependentAttachmentApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model()
        cls.owner = users.objects.create_user(username="split_api_owner")
        cls.other = users.objects.create_user(username="split_api_other")
        cls.ws = Workspace.objects.create(name="split synthetic")
        cls.foreign_ws = Workspace.objects.create(name="split foreign")
        WorkspaceMember.objects.create(workspace=cls.ws, user=cls.owner,
                                       role=WorkspaceMember.Role.OWNER)
        WorkspaceMember.objects.create(workspace=cls.foreign_ws, user=cls.other,
                                       role=WorkspaceMember.Role.OWNER)
        cls.renewal = Renewal.objects.create(
            workspace=cls.ws, customer_reference="SPLIT-API-TEST",
            full_name="Synthetic", expires_on=date(2027, 7, 1))
        cls.item = RenewalAttachment.objects.create(
            renewal=cls.renewal, display_name="synthetic.pdf",
            content_type="application/pdf", byte_size=14, sha256="a" * 64)

    def test_owner_sees_independent_metadata_without_file_capabilities(self):
        self.client.force_login(self.owner)
        url = reverse("api-renewal-attachments", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertEqual(len(response.json()["results"]), 1)
        row = response.json()["results"][0]
        self.assertEqual(row["id"], str(self.item.id))
        self.assertNotIn("storage_key", row)
        self.assertNotIn("sha256", row)
        self.assertFalse(response.json()["capabilities"]["download"])
        self.assertFalse(response.json()["capabilities"]["upload"])
        self.assertFalse(response.json()["capabilities"]["delete"])
        self.assertEqual(self.client.post(url, data={},
            content_type="application/json").status_code, 403)
        detail = reverse("api-renewal-attachment-detail", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "attachment_id": self.item.pk})
        self.assertEqual(self.client.get(detail).status_code, 403)
        self.assertEqual(self.client.delete(detail).status_code, 403)

    def test_foreign_tenant_never_sees_document(self):
        self.client.force_login(self.other)
        url = reverse("api-renewal-attachments", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})
        self.assertEqual(self.client.get(url).status_code, 404)
