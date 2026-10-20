import os
from io import StringIO
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase, override_settings

from .models import Renewal, Workspace, WorkspaceMember


class PreviewSeedTests(TestCase):
    def test_refuses_without_explicit_preview_mode(self):
        with override_settings(VENCIRA_ENV="development"):
            with patch.dict(os.environ, {"VENCIRA_PREVIEW_MODE": "0"}):
                with self.assertRaises(CommandError):
                    call_command("seed_preview", stdout=StringIO())

    def test_seed_is_synthetic_and_idempotent(self):
        with override_settings(VENCIRA_ENV="development"):
            with patch.dict(os.environ, {"VENCIRA_PREVIEW_MODE": "1"}):
                first = StringIO()
                call_command("seed_preview", stdout=first)
                self.assertIn("vencira_demo", first.getvalue())
                self.assertEqual(Renewal.objects.count(), 6)
                self.assertEqual(WorkspaceMember.objects.count(), 1)
                user = get_user_model().objects.get(username="vencira_demo")
                self.assertFalse(user.is_superuser)
                self.assertFalse(user.is_staff)
                self.assertTrue(user.has_usable_password())
                before = user.password
                call_command("seed_preview", stdout=StringIO())
                user.refresh_from_db()
                self.assertNotEqual(before, user.password)
                self.assertEqual(Renewal.objects.count(), 6)
                self.assertEqual(Workspace.objects.count(), 1)
