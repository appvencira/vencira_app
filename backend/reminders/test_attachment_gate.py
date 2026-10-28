"""Access tests use synthetic accounts and temporary Django test databases."""
from datetime import date
from django.contrib.auth import get_user_model
from django.test import TestCase
from .attachment_gate import accessible_attachment_queryset, may_download_attachment
from .models import Renewal, RenewalAttachment, Workspace, WorkspaceMember


class AttachmentGateTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        user = get_user_model()
        cls.owner = user.objects.create_user(username="att_owner")
        cls.member = user.objects.create_user(username="att_member")
        cls.stranger = user.objects.create_user(username="att_other")
        cls.ws = Workspace.objects.create(name="ATT demo one")
        cls.other = Workspace.objects.create(name="ATT demo two")
        cls.owner_mem = WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.owner, role="owner")
        cls.member_mem = WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.member, role="member")
        cls.other_mem = WorkspaceMember.objects.create(
            workspace=cls.other, user=cls.stranger, role="owner")
        rows = (
            (cls.ws, cls.member),
            (cls.ws, cls.owner),
            (cls.other, cls.stranger),
        )
        cls.items = []
        for i, (ws, assigned) in enumerate(rows):
            renewal = Renewal.objects.create(
                workspace=ws, assigned_to=assigned,
                customer_reference=f"DEMO-ATT-{i}",
                full_name=f"Demo {i}", expires_on=date(2027, 1, 2))
            cls.items.append(RenewalAttachment.objects.create(
                renewal=renewal, display_name="demo.pdf",
                content_type="application/pdf", byte_size=10,
                sha256="a" * 64, state="clean"))

    def test_scope_owner_member_and_foreign_workspace(self):
        self.assertEqual(accessible_attachment_queryset(self.owner_mem).count(), 2)
        self.assertEqual(accessible_attachment_queryset(self.member_mem).count(), 1)
        self.assertEqual(accessible_attachment_queryset(self.other_mem).count(), 1)
        self.assertFalse(accessible_attachment_queryset(self.member_mem).filter(
            pk=self.items[1].pk).exists())
        self.assertFalse(accessible_attachment_queryset(self.owner_mem).filter(
            pk=self.items[2].pk).exists())

    def test_even_clean_metadata_cannot_enable_download(self):
        for item in self.items:
            self.assertFalse(may_download_attachment(
                attachment=item, membership=self.owner_mem))
            self.assertFalse(may_download_attachment(
                attachment=item, membership=self.member_mem))
        self.items[0].state = "quarantined"
        self.assertFalse(may_download_attachment(
            attachment=self.items[0], membership=self.member_mem))
