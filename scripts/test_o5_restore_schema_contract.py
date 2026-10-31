"""Pure contract tests for versioned O5 restore-schema checker."""
import unittest
from scripts.o5_restore_schema_contract import (
    BASELINE, O5SchemaError, validate_reminders_restore
)

BASE = "0001_initial\n0002_loginattemptbucket\n" + BASELINE
TABLES = "django_migrations\nreminders_workspace\nreminders_renewal"


class O5RestoreSchemaContractTests(unittest.TestCase):
    def test_legacy_exact_baseline_passes(self):
        result = validate_reminders_restore(BASE, TABLES)
        self.assertEqual(result["verified_baseline"], BASELINE)
        self.assertFalse(result["release_authorized"])

    def test_newer_reminders_migration_passes(self):
        result = validate_reminders_restore(
            BASE + "\n0015_renewal_reminder_drafts\n0018_draft_reasons", TABLES
        )
        self.assertEqual(result["migration_count"], 5)

    def test_missing_baseline_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "BASELINE_MISSING"):
            validate_reminders_restore("0001_initial\n0018_draft_reasons", TABLES)

    def test_missing_initial_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "BASELINE_MISSING"):
            validate_reminders_restore(BASELINE, TABLES)

    def test_missing_renewal_table_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "TABLES_MISSING"):
            validate_reminders_restore(BASE, "django_migrations\nreminders_workspace")

    def test_duplicate_migration_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "DUPLICATE"):
            validate_reminders_restore(BASE + "\n" + BASELINE, TABLES)

    def test_injection_like_inventory_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "INVALID_SCHEMA_INVENTORY"):
            validate_reminders_restore(BASE + "\n0019_bad';DROP TABLE", TABLES)

    def test_duplicate_table_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "DUPLICATE"):
            validate_reminders_restore(BASE, TABLES + "\nreminders_workspace")

    def test_empty_inventory_fails(self):
        with self.assertRaisesRegex(O5SchemaError, "INVALID_SCHEMA_INVENTORY"):
            validate_reminders_restore("", TABLES)

    def test_arbitrary_later_migration_does_not_remove_requirement(self):
        with self.assertRaisesRegex(O5SchemaError, "BASELINE_MISSING"):
            validate_reminders_restore("0001_initial\n0027_renewal_attachment_metadata", TABLES)


if __name__ == "__main__":
    unittest.main()
