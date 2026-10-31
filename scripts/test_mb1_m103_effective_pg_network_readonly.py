"""Pure M1-03 contract tests. No Docker, SQL, host services or credentials."""
import unittest
from scripts.audit_mb1_m103_effective_pg_network_readonly import (
    db_labels, validate_sql_counts, categorize_network_members
)


def numbers():
    return dict.fromkeys((
        "login_roles", "superuser_login", "ddl_login", "replication_login",
        "public_schema_create_login", "business_table_dml_login",
        "client_sessions_other", "other_active_transactions",
        "hba_host_rules", "hba_trust_rules", "hba_unrestricted_address_rules",
        "hba_invalid_rules",
    ), 0)


class M103ReadOnlyAuditContracts(unittest.TestCase):
    def test_valid_aggregated_census_is_accepted(self):
        data = numbers()
        data["superuser_login"] = 1
        self.assertEqual(validate_sql_counts(data), data)

    def test_sql_columns_missing_fail_closed(self):
        data = numbers()
        del data["hba_trust_rules"]
        with self.assertRaises(ValueError):
            validate_sql_counts(data)

    def test_sql_extra_columns_fail_closed(self):
        data = numbers()
        data["password"] = 1
        with self.assertRaises(ValueError):
            validate_sql_counts(data)

    def test_sql_negative_counts_fail_closed(self):
        data = numbers()
        data["client_sessions_other"] = -1
        with self.assertRaises(ValueError):
            validate_sql_counts(data)

    def test_boolean_count_fail_closed(self):
        data = numbers()
        data["login_roles"] = True
        with self.assertRaises(ValueError):
            validate_sql_counts(data)

    def test_project_service_from_labels(self):
        item = {"Config": {"Labels": {
            "com.docker.compose.project": "vencira_preview",
            "com.docker.compose.service": "db",
        }}}
        self.assertEqual(db_labels(item), ("vencira_preview", "db"))

    def test_single_network_count(self):
        db = {"NetworkSettings": {"Networks": {"lab": {}}}}
        networks = {"lab": {"Containers": {
            "123": {"Name": "db"}, "456": {"Name": "api"}
        }}}
        self.assertEqual(
            categorize_network_members(db, networks, "vencira_localcheck"),
            {"network_count": 1, "member_count": 2},
        )

    def test_missing_network_inventory_fail_closed(self):
        db = {"NetworkSettings": {"Networks": {"lab": {}}}}
        with self.assertRaises(ValueError):
            categorize_network_members(db, {}, "vencira_localcheck")

    def test_empty_member_listing_fail_closed(self):
        db = {"NetworkSettings": {"Networks": {"lab": {}}}}
        with self.assertRaises(ValueError):
            categorize_network_members(db, {"lab": {"Containers": {}}},
                                       "vencira_localcheck")

    def test_invalid_member_name_fail_closed(self):
        db = {"NetworkSettings": {"Networks": {"lab": {}}}}
        with self.assertRaises(ValueError):
            categorize_network_members(
                db, {"lab": {"Containers": {"abc": {"Name": ""}}}},
                "vencira_localcheck"
            )


if __name__ == "__main__":
    unittest.main()
