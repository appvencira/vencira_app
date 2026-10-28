"""End-to-end API permission tests using fictional data only."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from .models import Renewal, RenewalAttachment, Workspace, WorkspaceMember


class AttachmentApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model()
        cls.owner = users.objects.create_user(username="att_api_owner")
        cls.member = users.objects.create_user(username="att_api_member")
        cls.foreign = users.objects.create_user(username="att_api_foreign")
        cls.ws = Workspace.objects.create(name="ATT API synthetic")
        cls.other = Workspace.objects.create(name="ATT other synthetic")
        for ws, user, role in ((cls.ws, cls.owner, "owner"),
                               (cls.ws, cls.member, "member"),
                               (cls.other, cls.foreign, "owner")):
            WorkspaceMember.objects.create(workspace=ws, user=user, role=role)
        cls.renewal = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="TEST-001", full_name="Test",
            expires_on=date(2027, 3, 4))
        cls.item = RenewalAttachment.objects.create(
            renewal=cls.renewal, display_name="demo.pdf",
            content_type="application/pdf", byte_size=100, sha256="b"*64,
            state="clean")

    def url(self):
        return reverse("api-renewal-attachments", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk})

    def detail_url(self):
        return reverse("api-renewal-attachment-detail", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "attachment_id": self.item.pk})

    def test_anonymous_and_foreign_cannot_list(self):
        self.assertIn(self.client.get(self.url()).status_code, (401, 403))
        self.client.force_login(self.foreign)
        self.assertEqual(self.client.get(self.url()).status_code, 404)

    def test_assigned_member_can_list_only_metadata(self):
        self.client.force_login(self.member)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        self.assertFalse(response.json()["upload_enabled"])
        self.assertEqual(response.json()["capabilities"], {
            "upload": False, "download": False, "delete": False,
            "reason": "SECURITY_REVIEW_PENDING",
        })
        self.assertEqual(len(response.json()["results"]), 1)
        row = response.json()["results"][0]
        self.assertFalse(row["download_enabled"])
        self.assertFalse(row["delete_enabled"])
        self.assertNotIn("storage_key", row)
        self.assertNotIn("sha256", row)

    def test_owner_can_list_but_cannot_download_or_delete(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.client.get(self.url()).status_code, 200)
        self.assertEqual(self.client.get(self.detail_url()).status_code, 403)
        self.assertEqual(self.client.delete(self.detail_url()).status_code, 403)
        self.assertEqual(self.client.post(self.url(), data={}, content_type="application/json").status_code, 403)

    def test_unassigned_member_cannot_list_another_renewal(self):
        other = Renewal.objects.create(
            workspace=self.ws, assigned_to=self.owner,
            customer_reference="TEST-002", full_name="Test",
            expires_on=date(2027, 4, 5))
        url = reverse("api-renewal-attachments", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": other.pk})
        self.client.force_login(self.member)
        self.assertEqual(self.client.get(url).status_code, 404)

    def test_foreign_member_cannot_read_or_modify_file_endpoint(self):
        self.client.force_login(self.foreign)
        for response in (
            self.client.get(self.detail_url()),
            self.client.delete(self.detail_url()),
            self.client.post(self.url(), data={},
                             content_type="application/json"),
        ):
            self.assertEqual(response.status_code, 404)


    def test_attachment_cannot_be_accessed_through_another_renewal(self):
        other = Renewal.objects.create(
            workspace=self.ws,
            assigned_to=self.member,
            customer_reference="TEST-CROSS-RENEWAL",
            full_name="Synthetic",
            expires_on=date(2027, 6, 1),
        )
        url = reverse("api-renewal-attachment-detail", kwargs={
            "workspace_id": self.ws.pk,
            "renewal_id": other.pk,
            "attachment_id": self.item.pk,
        })
        self.client.force_login(self.owner)
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.delete(url).status_code, 404)

    def test_clean_state_never_grants_document_access(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.item.state, "clean")
        for method in (self.client.get, self.client.delete):
            response = method(self.detail_url())
            self.assertEqual(response.status_code, 403)
            self.assertEqual(response["Cache-Control"], "no-store")
            self.assertNotIn("Content-Disposition", response)
            self.assertNotIn("storage_key", response.content.decode())

    def test_manifest_does_not_expose_private_identifiers(self):
        self.client.force_login(self.owner)
        response = self.client.get(self.url())
        self.assertEqual(response.status_code, 200)
        payload = response.content.decode()
        for forbidden in ("storage_key", "sha256", "scan_evidence",
                          "private_path", "download_url"):
            self.assertNotIn(forbidden, payload)
        self.assertFalse(response.json()["capabilities"]["download"])

    def test_missing_file_is_not_exposed_as_a_download(self):
        self.client.force_login(self.owner)
        missing = reverse("api-renewal-attachment-detail", kwargs={
            "workspace_id": self.ws.pk, "renewal_id": self.renewal.pk,
            "attachment_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"})
        response = self.client.get(missing)
        self.assertEqual(response.status_code, 404)
        self.assertNotIn("Content-Disposition", response)
