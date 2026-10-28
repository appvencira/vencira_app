from django.test import SimpleTestCase
from .attachment_migration_guard import attachment_release_preflight


class AttachmentMigrationGuardTests(SimpleTestCase):
    def test_current_graph_blocks_attachment_release(self):
        allowed, reason = attachment_release_preflight()
        self.assertFalse(allowed)
        self.assertEqual(reason, "MFA_DEPENDENCY_BLOCKS_ATTACHMENTS")
