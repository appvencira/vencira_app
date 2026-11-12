"""Mutation tests for the D27-D28 fail-closed transition contract."""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "d27d28_audit", ROOT / "scripts/main_d27d28_operational_boundary_audit.py"
)
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class D27D28AuditTests(unittest.TestCase):
    def setUp(self):
        self.source = {path: module.read(path) for path in (
            module.PRODUCTION_URLS,
            module.PRODUCTION_SETTINGS,
            module.ANDROID_MAIN,
            module.STARTUP,
            module.ISSUER,
        )}

    def test_current_main_denies_operational_native_issuer(self):
        self.assertEqual(module.audit_source(self.source), ())

    def test_refuses_missing_sources_and_malformed_python(self):
        self.assertIn("incomplete_source_inventory", module.audit_source({}))
        damaged = dict(self.source)
        damaged[module.ISSUER] = "def invalid(: pass"
        self.assertIn("invalid_python_source", module.audit_source(damaged))

    def test_refuses_moving_lab_urls_into_production(self):
        for lab in module.CANDIDATE_MODULES:
            damaged = dict(self.source)
            damaged[module.PRODUCTION_URLS] += "\n# " + lab + "\n"
            if lab in ("test_d22_urls", "test_i8k_recovery_urls"):
                self.assertIn(
                    "native_lab_or_unreviewed_operational_routes_present",
                    module.audit_source(damaged),
                )

    def test_refuses_bearer_or_issuer_policy_flip(self):
        damaged = dict(self.source)
        damaged[module.PRODUCTION_SETTINGS] = damaged[
            module.PRODUCTION_SETTINGS
        ].replace("VENCIRA_NATIVE_BEARER_ENABLED = False",
                  "VENCIRA_NATIVE_BEARER_ENABLED = True")
        self.assertIn("native_bearer_release_fence_changed",
                      module.audit_source(damaged))
        damaged = dict(self.source)
        damaged[module.ISSUER] = damaged[module.ISSUER].replace(
            'raise NativeIssuerUnavailable("Native mobile issuer unavailable")',
            'return True',
        )
        self.assertIn("native_issuer_hard_deny_missing",
                      module.audit_source(damaged))

    def test_refuses_android_auth_before_issuer_review(self):
        damaged = dict(self.source)
        damaged[module.ANDROID_MAIN] += "\n// NativeLoginScreen(\n"
        self.assertIn("android_operational_login_routed_without_review",
                      module.audit_source(damaged))
        damaged = dict(self.source)
        damaged[module.STARTUP] += "\n// NativeHttpAuthPort(\n"
        self.assertIn("startup_fence_changed",
                      module.audit_source(damaged))


if __name__ == "__main__":
    unittest.main()
