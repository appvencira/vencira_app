#!/usr/bin/env python3
"""I8-M test-only TLS bridge startup-denial regression.

Runs the bridge only with intentionally incomplete environment variables;
it MUST terminate before importing Django, opening sockets or loading keys.
No Docker, DB, remote connection, certificates or release authorization.
"""
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / "scripts" / "native_i8k_https_server.py"
REQUIRED = {
    "VENCIRA_ENV": "test",
    "VENCIRA_NATIVE_SERVICE_CANDIDATE": "1",
    "VENCIRA_I8K_RECOVERY_LAB": "1",
    "VENCIRA_I8K_NETWORK_ISOLATED": "1",
    "VENCIRA_DB_ENGINE": "postgresql",
    "POSTGRES_DB": "i8klab",
}


class I8MBridgeDenial(unittest.TestCase):
    def denied(self, overrides):
        # An explicit, minimal process environment prevents inherited
        # operational settings/credentials from entering this regression.
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
        env.update(REQUIRED)
        env.update(overrides)
        outcome = subprocess.run(
            [sys.executable, str(BRIDGE)],
            env=env, cwd=str(ROOT),
            capture_output=True, text=True, timeout=8,
            check=False,
        )
        self.assertNotEqual(outcome.returncode, 0)
        self.assertIn("NATIVE_I8K_SERVER_GUARD=DENIED",
                      outcome.stdout + outcome.stderr)
        self.assertNotIn("NATIVE_I8K_HTTPS_SERVER_READY=OK",
                         outcome.stdout + outcome.stderr)

    def test_all_required_variables_missing_are_denied(self):
        for variable in REQUIRED:
            with self.subTest(missing=variable):
                env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
                env.update({k: v for k, v in REQUIRED.items() if k != variable})
                result = subprocess.run(
                    [sys.executable, str(BRIDGE)],
                    env=env, cwd=str(ROOT),
                    capture_output=True, text=True, timeout=8,
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("NATIVE_I8K_SERVER_GUARD=DENIED",
                              result.stdout + result.stderr)
                self.assertNotIn("NATIVE_I8K_HTTPS_SERVER_READY=OK",
                                 result.stdout + result.stderr)

    def test_wrong_values_are_denied(self):
        for key, wrong in [
            ("VENCIRA_ENV", "production"),
            ("VENCIRA_ENV", "development"),
            ("VENCIRA_NATIVE_SERVICE_CANDIDATE", "0"),
            ("VENCIRA_I8K_RECOVERY_LAB", "0"),
            ("VENCIRA_I8K_NETWORK_ISOLATED", "0"),
            ("VENCIRA_DB_ENGINE", "sqlite"),
            ("POSTGRES_DB", "vencira"),
        ]:
            with self.subTest(variable=key, value=wrong):
                self.denied({key: wrong})


if __name__ == "__main__":
    unittest.main(verbosity=1)
    print("MAIN_I8M_TLS_BRIDGE_NEGATIVE_GUARD=PASS")
    print("MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED")
    print("MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
