"""Fail-closed migration release guard for independently shipping C-FICHA.

This is a planner, not a migration executor. In particular, applying the
attachment migration must never silently apply MFA schema.
"""
from django.db.migrations.loader import MigrationLoader

BASELINE = ("reminders", "0018_draft_reasons")
ATTACHMENTS = ("reminders", "0027_renewal_attachment_metadata")
MFA = ("reminders", "0019_user_mfa_state")


def attachment_release_preflight(*, loader=None):
    """Return a machine-checkable refusal unless attachment path avoids MFA."""
    loader = loader or MigrationLoader(None)
    graph = loader.graph
    try:
        ancestry = set(graph.forwards_plan(ATTACHMENTS))
    except (KeyError, ValueError) as exc:
        return False, "INVALID_MIGRATION_GRAPH"
    if BASELINE not in ancestry:
        return False, "BASELINE_MISSING"
    if MFA in ancestry or any(
        app == "reminders" and name.startswith(tuple(
            f"{number:04d}_" for number in range(19, 27)
        )) for app, name in ancestry
    ):
        return False, "MFA_DEPENDENCY_BLOCKS_ATTACHMENTS"
    return True, "MFA_INDEPENDENT_PATH"
