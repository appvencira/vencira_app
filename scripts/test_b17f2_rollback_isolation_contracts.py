#!/usr/bin/env python3
"""B17F2: static rollback/isolation regression. No shell execution or network."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent
CASES = {
    "validate_mfa_active_rollback_pg17.sh": {
        "branch": "integration/local-e2e-prep",
        "markers": [
            'sudo docker network create --internal "$NET"',
            'sudo docker rm -f "$DB"',
            'sudo docker network rm "$NET"',
            'mfa_rollback_guard --candidate-lacks-mfa',
            'mfa_rollback_guard --candidate-enforces-mfa',
            'MFA_DESTRUCTIVE_SCHEMA_DOWNGRADE=NOT_RUN',
            'MFA_PRODUCTION_ROLLBACK_AUTHORIZED=NO',
            'NO_DEPLOY_NO_LIVE_MIGRATION=1',
        ],
    },
    "rehearse_c_ficha_split_readonly.sh": {
        "branch": "feature/c-ficha-independent-attachments",
        "markers": [
            'sudo docker network create --internal "$NET"',
            'sudo docker rm -f "$DB"',
            'sudo docker network rm "$NET"',
            'migrate reminders 0018_draft_reasons --noinput',
            'migrate renewal_attachments 0001_initial --noinput',
            'C_FICHA_SPLIT_PG17_RESULT=$rc',
            'NO_DEPLOY_NO_LIVE_MIGRATION=1',
        ],
    },
}
class B17F2IsolationContracts(unittest.TestCase):
    def check(self, name, body):
        cfg = CASES[name]
        self.assertIn('test "$(git branch --show-current)" = '+cfg["branch"], body)
        self.assertIn("set -Eeuo pipefail", body)
        self.assertIn("trap ", body)
        for marker in cfg["markers"]:
            self.assertIn(marker, body, f"{name}: missing {marker}")
        self.assertNotIn("docker compose down -v", body)
        self.assertNotIn("docker system prune", body)
        self.assertNotIn("--network host", body)
        self.assertNotIn("--publish", body)
        self.assertNotIn("-p 5432:", body)
        self.assertNotIn("vencira_localcheck-db-1", body)
    def test_isolated_mfa_rollback_rehearsal(self):
        self.check("validate_mfa_active_rollback_pg17.sh",
                   (ROOT/"validate_mfa_active_rollback_pg17.sh").read_text())
    def test_isolated_attachment_schema_rehearsal(self):
        self.check("rehearse_c_ficha_split_readonly.sh",
                   (ROOT/"rehearse_c_ficha_split_readonly.sh").read_text())
    def test_reject_mutated_rollback_contract(self):
        name="validate_mfa_active_rollback_pg17.sh"
        body=(ROOT/name).read_text()
        with self.assertRaises(AssertionError):
            self.check(name,body.replace('sudo docker network create --internal "$NET"',
                                         'sudo docker network create "$NET"'))
    def test_reject_mutated_attachments_contract(self):
        name="rehearse_c_ficha_split_readonly.sh"
        body=(ROOT/name).read_text()
        with self.assertRaises(AssertionError):
            self.check(name,body.replace('sudo docker network rm "$NET"',
                                         'echo keep_network'))
    def test_reject_live_db_reference(self):
        name="rehearse_c_ficha_split_readonly.sh"
        with self.assertRaises(AssertionError):
            self.check(name,(ROOT/name).read_text()+'\nvencira_localcheck-db-1\n')

if __name__ == "__main__":
    unittest.main(verbosity=2)
