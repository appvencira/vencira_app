#!/usr/bin/env python3
"""Self-contained regression tests for the read-only inventory."""
import tempfile
import unittest
from pathlib import Path

from g14_mfa_writer_inventory import find_candidates


class WriterInventoryTests(unittest.TestCase):
    def scan(self, source):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.py"
            path.write_text(source, encoding="utf-8")
            return find_candidates(path)

    def test_mfa_model_update_is_detected(self):
        hits = self.scan(
            "from reminders.models import UserMfaState\n"
            "UserMfaState.objects.filter(user_id=3).update(session_epoch=2)\n"
        )
        self.assertTrue(hits)

    def test_mfa_state_assignment_is_detected(self):
        hits = self.scan(
            "def change(state):\n"
            "    state.enabled = True\n"
            "    state.save(update_fields=['enabled'])\n"
        )
        self.assertTrue(any(kind == "mfa_field_assignment" for _, kind in hits))

    def test_non_mfa_module_without_state_writes_ignored(self):
        hits = self.scan(
            "from other.models import Item\n"
            "Item.objects.filter(pk=1).update(title='ok')\n"
        )
        self.assertEqual(hits, [])

    def test_inventory_does_not_execute_source(self):
        hits = self.scan(
            "raise RuntimeError('must not execute')\n"
            "from reminders.models import UserMfaState\n"
            "UserMfaState.objects.filter(pk=1).delete()\n"
        )
        self.assertTrue(hits)


if __name__ == "__main__":
    unittest.main()
