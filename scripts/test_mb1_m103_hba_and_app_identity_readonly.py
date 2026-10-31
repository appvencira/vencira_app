"""Pure tests for M1-03 HBA/SQL-role classification; no Docker or SQL calls."""
import json
import unittest
from scripts.audit_mb1_m103_hba_and_app_identity_readonly import (
    classify_identity, config_env, parse_counts,
)


def census():
    return {
        "local_trust": 5, "host_trust": 1, "broad_host": 1,
        "broad_host_trust": 0, "broad_host_scram": 1,
        "broad_host_md5": 0, "broad_host_password": 0,
        "broad_host_other": 0, "invalid_rules": 0,
    }


class M103HbaAndIdentityContracts(unittest.TestCase):
    def test_local_trust_is_distinct_from_broad_scram(self):
        self.assertEqual(parse_counts(json.dumps(census())), census())

    def test_broad_host_trust_can_be_identified(self):
        v = census()
        v["host_trust"] = 2
        v["broad_host_trust"] = 1
        v["broad_host_scram"] = 0
        self.assertEqual(parse_counts(json.dumps(v))["broad_host_trust"], 1)

    def test_incomplete_auth_classification_fails(self):
        v = census()
        v["broad_host_scram"] = 0
        with self.assertRaisesRegex(ValueError, "INCOMPLETE"):
            parse_counts(json.dumps(v))

    def test_inconsistent_broad_trust_count_fails(self):
        v = census()
        v["broad_host_trust"] = 1
        with self.assertRaisesRegex(ValueError, "INCOMPLETE"):
            parse_counts(json.dumps(v))

    def test_out_of_range_or_boolean_count_fails(self):
        v = census()
        v["host_trust"] = True
        with self.assertRaisesRegex(ValueError, "INVALID"):
            parse_counts(json.dumps(v))

    def test_no_unexpected_fields(self):
        v = census()
        v["secret"] = "confidential"
        with self.assertRaisesRegex(ValueError, "UNEXPECTED"):
            parse_counts(json.dumps(v))

    def test_api_db_identity_matching_superuser(self):
        self.assertEqual(classify_identity("worker", "worker", "t"), "YES")

    def test_api_db_identity_matching_non_superuser(self):
        self.assertEqual(classify_identity("worker", "worker", "f"), "NO")

    def test_different_api_user_must_not_claim_superuser(self):
        self.assertEqual(classify_identity("worker", "owner", "t"), "NOT_MATCHED")

    def test_missing_config_must_not_claim_yes(self):
        self.assertEqual(classify_identity(None, "owner", "t"), "UNKNOWN")

    def test_env_values_not_disclosed_by_helpers(self):
        item = {"Config": {"Env": ["POSTGRES_USER=worker","POSTGRES_PASSWORD=secret"]}}
        self.assertEqual(config_env(item,"POSTGRES_USER"),"worker")
        self.assertIsNone(config_env(item,"POSTGRES_HOST"))


if __name__ == "__main__":
    unittest.main()
