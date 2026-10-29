#!/usr/bin/env python3
"""B17F negative regression tests: synthetic scripts only; no Docker or network."""
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

AUDITOR = Path(__file__).with_name("b17f_static_release_guard_audit.py")
spec = importlib.util.spec_from_file_location("b17f_auditor", AUDITOR)
audit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_module)

class B17FNegativeTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory(prefix="b17f-negative-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        scripts = self.root / "scripts"
        scripts.mkdir()
        # Complete expected inventory plus seven conservative API deploy scripts.
        expected = audit_module.MODES["web"] | audit_module.MODES["schema"]
        extras = {"deploy_synthetic_%02d.sh" % n for n in range(7)}
        for name in expected | extras:
            mode = ("web" if name in audit_module.MODES["web"] else
                    "schema" if name in audit_module.MODES["schema"] else "api")
            (scripts / name).write_text(
                "#!/bin/bash\nset -Eeuo pipefail\n"
                "bash scripts/mfa_legacy_deploy_guard_readonly.sh " + mode +
                "\necho synthetic\n", encoding="utf-8")
        (scripts / "mfa_release_entrypoint.sh").write_text(
            "\n".join(audit_module.EXPECTED["mfa_release_entrypoint.sh"]), encoding="utf-8")
        (scripts / "mfa_legacy_deploy_guard_readonly.sh").write_text(
            "\n".join(audit_module.EXPECTED["mfa_legacy_deploy_guard_readonly.sh"]), encoding="utf-8")
    def result(self):
        return audit_module.audit(self.root)
    def test_baseline_pass(self):
        count, issues = self.result()
        self.assertEqual(count, 16)
        self.assertEqual(issues, [])
    def test_missing_guard_blocked(self):
        p = self.root / "scripts/deploy_synthetic_00.sh"
        p.write_text("#!/bin/bash\necho no guard\n", encoding="utf-8")
        self.assertTrue(any("missing/duplicate" in s for s in self.result()[1]))
    def test_duplicate_guard_blocked(self):
        p = self.root / "scripts/deploy_synthetic_01.sh"
        p.write_text(p.read_text() + "bash scripts/mfa_legacy_deploy_guard_readonly.sh api\n")
        self.assertTrue(any("missing/duplicate" in s for s in self.result()[1]))
    def test_wrong_mode_blocked(self):
        p = self.root / "scripts/deploy_synthetic_02.sh"
        p.write_text(p.read_text().replace("guard_readonly.sh api", "guard_readonly.sh web"))
        self.assertTrue(any("missing/duplicate" in s for s in self.result()[1]))
    def test_mutation_before_guard_blocked(self):
        p = self.root / "scripts/deploy_synthetic_03.sh"
        p.write_text("#!/bin/bash\ndocker compose up -d\n" + p.read_text())
        self.assertTrue(any("potential mutation before guard" in s for s in self.result()[1]))
    def test_dynamic_execution_before_guard_blocked(self):
        p = self.root / "scripts/deploy_synthetic_04.sh"
        p.write_text("#!/bin/bash\neval \"$COMMAND\"\n" + p.read_text())
        self.assertTrue(any("dynamic execution before guard" in s for s in self.result()[1]))
    def test_new_deploy_without_guard_blocked(self):
        (self.root / "scripts/deploy_extra.sh").write_text("#!/bin/bash\necho unguarded\n")
        self.assertTrue(any("deploy_extra.sh" in s for s in self.result()[1]))
    def test_missing_release_block_invariant(self):
        p = self.root / "scripts/mfa_release_entrypoint.sh"
        p.write_text(p.read_text().replace("OPERATIONAL_AUTHORIZATION_REQUIRED", "REMOVED"))
        self.assertTrue(any("missing invariant" in s for s in self.result()[1]))
    def test_missing_expected_deploy_blocked(self):
        (self.root / "scripts/deploy_macro_a_ui_web_guarded.sh").unlink()
        self.assertTrue(any("expected web script missing" in s for s in self.result()[1]))

if __name__ == "__main__":
    unittest.main(verbosity=2)
