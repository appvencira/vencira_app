#!/usr/bin/env python3
"""O5 restore baseline validator: explicit minimum migration, not latest-name pin.

Pure, no database or filesystem access. Used only after a restore into
disposable PostgreSQL. A PASS means minimum schema presence, not application
compatibility, remote recoverability, anti-rollback, or a release approval.
"""
import argparse
import re
import sys

BASELINE = "0014_renewal_outcomes"
REQUIRED_TABLES = frozenset({
    "django_migrations",
    "reminders_workspace",
    "reminders_renewal",
})
MIGRATION = re.compile(r"^[0-9]{4}_[a-z][a-z0-9_]{0,100}$")
TABLE = re.compile(r"^[a-z][a-z0-9_]{0,100}$")


class O5SchemaError(ValueError):
    pass


def _valid_lines(text, pattern):
    if type(text) is not str or not text or len(text) > 128000:
        raise O5SchemaError("INVALID_SCHEMA_INVENTORY")
    values = text.splitlines()
    if not values or len(values) > 2000 or any(
        not pattern.fullmatch(value) for value in values
    ):
        raise O5SchemaError("INVALID_SCHEMA_INVENTORY")
    if len(values) != len(set(values)):
        raise O5SchemaError("DUPLICATE_SCHEMA_ENTRY")
    return set(values)


def validate_reminders_restore(migrations, tables):
    """Accept a restored baseline and newer extensions; reject missing basics."""
    names = _valid_lines(migrations, MIGRATION)
    existing = _valid_lines(tables, TABLE)
    if "0001_initial" not in names or BASELINE not in names:
        raise O5SchemaError("REQUIRED_REMINDERS_BASELINE_MISSING")
    if not REQUIRED_TABLES.issubset(existing):
        raise O5SchemaError("REQUIRED_RESTORED_TABLES_MISSING")
    return {
        "verified_baseline": BASELINE,
        "migration_count": len(names),
        "table_count": len(existing),
        "release_authorized": False,
    }


def main():
    parser = argparse.ArgumentParser(description="O5 restored schema minimum contract")
    parser.add_argument("--migrations", required=True)
    parser.add_argument("--tables", required=True)
    args = parser.parse_args()
    try:
        validate_reminders_restore(args.migrations, args.tables)
    except O5SchemaError:
        print("O5_RESTORED_BASELINE_SCHEMA=FAILED", file=sys.stderr)
        return 1
    print("O5_RESTORED_BASELINE_SCHEMA=OK")
    print("O5_RESTORE_SCHEMA_CHECK_IS_MINIMUM_ONLY=1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
