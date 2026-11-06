#!/usr/bin/env python3
"""G14-E2 synthetic tests for the untrusted bool proof import fence."""
import tempfile
import unittest
from pathlib import Path

from g14_e2_bool_issuance_fence import audit_tree, e1_references


class E2BooleanFenceTests(unittest.TestCase):
    def test_direct_import_denied(self):
        src = "from .g14_e1_locked_mfa_verifier import verify_candidate_password_and_totp\n"
        self.assertEqual(e1_references(src), [1])

    def test_renamed_import_denied(self):
        src = "from x.g14_e1_locked_mfa_verifier import verify_candidate_password_and_totp as proof\nproof()\n"
        self.assertEqual(e1_references(src), [1, 2])

    def test_module_reference_denied(self):
        src = "import g14_e1_locked_mfa_verifier as verifier\nverifier.verify_candidate_password_and_totp()\n"
        self.assertEqual(e1_references(src), [1, 2])

    def test_literal_getattr_denied(self):
        src = "import g14_e1_locked_mfa_verifier as verifier\ngetattr(verifier, 'verify_candidate_password_and_totp')\n"
        self.assertEqual(e1_references(src), [1, 2])

    def test_unrelated_source_allowed(self):
        self.assertEqual(e1_references("def unrelated():\n    return False\n"), [])

    def test_unreviewed_non_test_file_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "reminders"
            folder.mkdir()
            (folder / "views.py").write_text(
                "from native_mobile_service.g14_e1_locked_mfa_verifier import verify_candidate_password_and_totp\n",
                encoding="utf-8",
            )
            self.assertEqual(audit_tree(Path(tmp)), [("reminders/views.py", 1)])

    def test_test_file_excluded(self):
        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp) / "native_mobile_service"
            folder.mkdir()
            (folder / "test_e1.py").write_text(
                "from .g14_e1_locked_mfa_verifier import verify_candidate_password_and_totp\n",
                encoding="utf-8",
            )
            self.assertEqual(audit_tree(Path(tmp)), [])


if __name__ == "__main__":
    unittest.main()
