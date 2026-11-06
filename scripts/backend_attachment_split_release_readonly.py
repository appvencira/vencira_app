#!/usr/bin/env python3
"""Assess existing isolated attachment app for DEV release readiness.

AST/source-only inspection, no Django setup, queries, writes or live changes.
Release eligibility is deliberately fail-closed.
"""
from __future__ import annotations
import ast
from pathlib import Path

BASE = Path(__file__).resolve().parents[1] / "backend"
MIGRATION = BASE / "renewal_attachments/migrations/0001_initial.py"
SETTINGS = BASE / "config/settings.py"
ROUTER = BASE / "reminders/attachment_model_router.py"
MODELS = BASE / "reminders/models.py"
INDEPENDENT = BASE / "renewal_attachments/models.py"
API = BASE / "reminders/attachment_api.py"


def main() -> int:
    for file in (MIGRATION, SETTINGS, ROUTER, MODELS, INDEPENDENT, API):
        if not file.is_file():
            print(f"ATTACHMENT_SPLIT_REQUIRED_SOURCE_MISSING={file.name}")
            return 2
        ast.parse(file.read_text(encoding="utf-8"), filename=str(file))

    migration = MIGRATION.read_text()
    settings = SETTINGS.read_text()
    router = ROUTER.read_text()
    models = MODELS.read_text()
    independent = INDEPENDENT.read_text()
    api = API.read_text()

    independent_from_mfa = (
        '("reminders", "0018_draft_reasons")' in migration
        and '0027_renewal_attachment_metadata' not in migration
        and '0019_user_mfa_state' not in migration
    )
    test_only = (
        'VENCIRA_ATTACHMENT_SPLIT_REHEARSAL' in settings
        and 'if VENCIRA_ENV != "test":' in settings
        and 'Attachment split rehearsal only allowed in test' in settings
    )
    model_conflict = (
        "class RenewalAttachment(models.Model):" in models
        and "class RenewalAttachment(models.Model):" in independent
        and 'VENCIRA_M103_SPLIT_DELETE_LAB' in settings
    )
    router_test_only = (
        'Independent attachment model restricted to tests' in router
        and 'VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED' in router
    )
    no_mutating_attachment_api = (
        'status.HTTP_403_FORBIDDEN' in api
        and 'download_enabled": False' in api
        and 'delete_enabled": False' in api
    )

    checks = {
        "INDEPENDENT_0018_BASE": independent_from_mfa,
        "REGISTERED_ONLY_IN_TEST": test_only,
        "DUAL_MODEL_REGISTRATION_CONFLICT": model_conflict,
        "MODEL_ROUTER_TEST_ONLY": router_test_only,
        "ATTACHMENT_WRITE_AND_DOWNLOAD_BLOCKED": no_mutating_attachment_api,
    }
    for name, result in checks.items():
        print(f"ATTACHMENT_SPLIT_{name}={'YES' if result else 'NO'}")
    if not all(checks.values()):
        print("ATTACHMENT_SPLIT_SOURCE_REVIEW=FAIL")
        return 3
    print("ATTACHMENT_SPLIT_SOURCE_REVIEW=PASS")
    print("ATTACHMENT_SPLIT_EXISTING_INDEPENDENT_APP=YES")
    print("ATTACHMENT_SPLIT_DEV_RELEASE_READY=NO")
    print("ATTACHMENT_SPLIT_DEV_API_DEPLOY_EXECUTED=NO")
    print("ATTACHMENT_SPLIT_LIVE_DB_MIGRATED=NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
