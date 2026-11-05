#!/usr/bin/env python3
"""Synthetic parser tests: report-only lock site detection."""
import unittest
from g14_mfa_lock_order_report import lock_calls


class LockReportTests(unittest.TestCase):
    def test_two_locks_are_sorted_by_source_line(self):
        items = lock_calls(
            "def sample():\n"
            "    user.objects.select_for_update().get(pk=1)\n"
            "    mfa.objects.select_for_update().get(pk=1)\n"
        )
        self.assertEqual(items, [("sample", (2, 3))])

    def test_no_lock_returns_empty(self):
        self.assertEqual(lock_calls("def sample():\n    return 1\n"), [])

    def test_nonexecuted_syntax(self):
        self.assertEqual(lock_calls(
            "raise RuntimeError('not executed')\n"
            "def sample():\n"
            "    return thing.select_for_update()\n"
        ), [("sample", (3,))])


if __name__ == "__main__":
    unittest.main()
