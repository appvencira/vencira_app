#!/usr/bin/env python3
"""Synthetic tests for the source-only issuer call boundary."""
import tempfile
import unittest
from pathlib import Path

from g14_trusted_issuer_boundary import audit_tree, direct_issuer_calls


class TrustedIssuerBoundaryTests(unittest.TestCase):
    def test_direct_call_detected(self):
        source = "from .session_store import issue_verified_candidate_session\n" \
                 "issue_verified_candidate_session(user_id=3)\n"
        self.assertEqual(direct_issuer_calls(source), [2])

    def test_aliased_import_detected(self):
        source = "from .session_store import issue_verified_candidate_session as issue\n" \
                 "issue(user_id=3)\n"
        self.assertEqual(direct_issuer_calls(source), [2])

    def test_module_call_detected(self):
        source = "import session_store as store\n" \
                 "store.issue_verified_candidate_session(user_id=3)\n"
        self.assertEqual(direct_issuer_calls(source), [2])

    def test_no_execution_and_unrelated_call_ignored(self):
        source = "raise RuntimeError('must not execute')\n" \
                 "def sample():\n    return unrelated()\n"
        self.assertEqual(direct_issuer_calls(source), [])

    def test_literal_getattr_issuer_detected(self):
        source = (
            "import session_store as store\n"
            'getattr(store, "issue_verified_candidate_session")(user_id=3)\n'
        )
        self.assertEqual(direct_issuer_calls(source), [2])

    def test_literal_getattr_even_if_result_not_called(self):
        source = (
            "import session_store\n"
            'issuer = getattr(session_store, "issue_verified_candidate_session")\n'
        )
        self.assertEqual(direct_issuer_calls(source), [2])

    def test_unrelated_getattr_does_not_trigger(self):
        source = (
            "import session_store\n"
            'getattr(session_store, "unrelated")(user_id=3)\n'
        )
        self.assertEqual(direct_issuer_calls(source), [])

    def test_unreviewed_caller_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "other"
            folder.mkdir()
            (folder / "view.py").write_text(
                "issue_verified_candidate_session(user_id=3)\n",
                encoding="utf-8",
            )
            calls, violations = audit_tree(Path(tmp))
            self.assertEqual(calls, 1)
            self.assertEqual(violations, [("other/view.py", 1)])

    def test_reviewed_internal_caller_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "native_mobile_service"
            folder.mkdir()
            (folder / "g14_d3_candidate_boundary.py").write_text(
                "issue_verified_candidate_session(user_id=3)\n",
                encoding="utf-8",
            )
            calls, violations = audit_tree(Path(tmp))
            self.assertEqual(calls, 1)
            self.assertEqual(violations, [])


if __name__ == "__main__":
    unittest.main()
