"""D1-S: real route access-control regression with synthetic users/workspaces.

Does not exercise operational DEV, scanner, storage or actual binary uploads.
"""
from datetime import date

from django.contrib.auth import get_user_model
from django.test import TestCase

from .models import Renewal, Workspace, WorkspaceMember


class D1SWorkspaceAttachmentIsolation(TestCase):
    @classmethod
    def setUpTestData(cls):
        user_model = get_user_model()
        cls.owner_a = user_model.objects.create_user(
            username="d1s-owner-a", password="Synthetic-d1s-A-2026!"
        )
        cls.owner_b = user_model.objects.create_user(
            username="d1s-owner-b", password="Synthetic-d1s-B-2026!"
        )
        cls.member_a = user_model.objects.create_user(
            username="d1s-member-a", password="Synthetic-d1s-C-2026!"
        )
        cls.a = Workspace.objects.create(name="D1S Synthetic A")
        cls.b = Workspace.objects.create(name="D1S Synthetic B")
        WorkspaceMember.objects.create(
            user=cls.owner_a, workspace=cls.a, role=WorkspaceMember.Role.OWNER
        )
        WorkspaceMember.objects.create(
            user=cls.owner_b, workspace=cls.b, role=WorkspaceMember.Role.OWNER
        )
        WorkspaceMember.objects.create(
            user=cls.member_a, workspace=cls.a, role=WorkspaceMember.Role.MEMBER
        )
        cls.renewal_a = Renewal.objects.create(
            workspace=cls.a, customer_reference="D1S-ALPHA",
            expires_on=date(2027, 1, 5), assigned_to=cls.owner_a,
        )
        cls.renewal_b = Renewal.objects.create(
            workspace=cls.b, customer_reference="D1S-BETA",
            expires_on=date(2027, 2, 5), assigned_to=cls.owner_b,
        )

    def renewal_url(self, workspace, renewal):
        return f"/api/v1/workspaces/{workspace.pk}/renewals/{renewal.pk}/"

    def attachment_url(self, workspace, renewal):
        return self.renewal_url(workspace, renewal) + "attachments/"

    def test_foreign_workspace_rejects_renewal_and_attachments(self):
        self.client.force_login(self.owner_a)
        for url in (
            self.renewal_url(self.b, self.renewal_b),
            self.attachment_url(self.b, self.renewal_b),
        ):
            with self.subTest(url=url):
                self.assertEqual(self.client.get(url).status_code, 404)

    def test_member_cannot_read_unassigned_renewal_or_attachments(self):
        self.client.force_login(self.member_a)
        for url in (
            self.renewal_url(self.a, self.renewal_a),
            self.attachment_url(self.a, self.renewal_a),
        ):
            with self.subTest(url=url):
                self.assertEqual(self.client.get(url).status_code, 404)

    def test_authenticated_owner_attachment_upload_is_disabled(self):
        self.client.force_login(self.owner_a)
        url = self.attachment_url(self.a, self.renewal_a)
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        self.assertIs(response.json()["capabilities"]["upload"], False)
        self.assertIs(response.json()["capabilities"]["download"], False)
        self.assertIs(response.json()["capabilities"]["delete"], False)
        response = self.client.post(
            url, data="{}", content_type="application/json"
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response["Cache-Control"], "no-store")
