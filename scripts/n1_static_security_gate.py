#!/usr/bin/env python3
"""Fail-closed, read-only N1 release boundary guard.

Static evidence complements tests; it does not authorize token issuance.
Runs with stdlib, without Django settings, Docker, database or network.
"""
from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def verify():
    settings = read("backend/config/settings.py")
    config = read("backend/config/urls.py")
    routes = read("backend/reminders/urls.py")
    guard = read("backend/reminders/test_native_mobile_auth_boundary.py")
    lab_models = read("backend/native_sessions_lab/models.py")
    lab_migration = read("backend/native_sessions_lab/migrations/0001_initial.py")
    lab_epoch_migration = read(
        "backend/native_sessions_lab/migrations/0003_mobile_account_fence.py"
    )
    session_rules = read("backend/native_sessions_lab/session_rules.py")
    login_rules = read("backend/native_sessions_lab/login_rules.py")
    lab_urls = read("backend/native_sessions_lab/test_urls.py")

    failures = []
    checks = {
        "default_auth_session_only":
            '"rest_framework.authentication.SessionAuthentication"' in settings
            and "DEFAULT_AUTHENTICATION_CLASSES" in settings,
        "lab_env_test_guard":
            'if VENCIRA_ENV != "test":' in settings
            and 'raise ImproperlyConfigured("Native device session lab only allowed in test")' in settings,
        "lab_explicit_opt_in":
            'VENCIRA_NATIVE_SESSION_LAB = os.getenv("VENCIRA_NATIVE_SESSION_LAB", "0") == "1"' in settings,
        "lab_installed_only_under_guard":
            settings.count('INSTALLED_APPS.append("native_sessions_lab")') == 1,
        "lab_migrations_isolated":
            "native_sessions_lab" not in config
            and "native_sessions_lab" not in routes,
        "no_bearer_routes":
            "native_mobile_token_primitives" not in config
            and "native_mobile_token_primitives" not in routes
            and 'path("mobile/' not in routes
            and 'path("mobile/' not in config,
        "web_auth_guard_present":
            "test_bearer_header_cannot_authenticate_web_session_api" in guard
            and "test_device_session_lab_is_absent_from_normal_django" in guard,
        "ephemeral_schema_has_no_user_secret":
            "password" not in lab_models.lower()
            and "password" not in lab_migration.lower()
            and "refresh_digest" in lab_models
            and "SpentRefreshLab" in lab_migration,
        "account_revoke_fences_pending_mfa":
            "MobileAccountFenceLab" in lab_models
            and "auth_generation" in lab_epoch_migration
            and "generation=F(\"generation\") + 1" in session_rules
            and "MobileLoginChallengeLab.objects.filter(" in session_rules
            and "consumed_at=now" in session_rules
            and "record.auth_generation != account_generation_lab" in login_rules,
        "test_http_is_unreachable_from_operational_routes":
            "native_sessions_lab.test_urls" not in config
            and "native_sessions_lab.test_urls" not in routes
            and "test_http_contract" not in config
            and "test_http_contract" not in routes
            and 'path("api/v1/mobile/auth/password/"' in lab_urls,
        "lab_issuer_requires_epoch":
            "expected_generation," in session_rules
            and "expected_generation=None" not in session_rules,
    }

    for name, ok in checks.items():
        print(f"N1_STATIC_{name}={'OK' if ok else 'FAIL'}")
        if not ok:
            failures.append(name)

    # Require syntactically valid sources, independent of installed packages.
    for file in (
        "backend/config/settings.py",
        "backend/native_sessions_lab/models.py",
        "backend/native_sessions_lab/migrations/0001_initial.py",
        "backend/native_sessions_lab/session_rules.py",
        "backend/native_sessions_lab/tests.py",
        "backend/native_sessions_lab/test_pg17_race.py",
        "backend/native_sessions_lab/login_rules.py",
        "backend/native_sessions_lab/test_login_rules.py",
        "backend/native_sessions_lab/test_pg17_login_race.py",
        "backend/native_sessions_lab/migrations/0002_mobileloginchallengelab.py",
        "backend/native_sessions_lab/migrations/0003_mobile_account_fence.py",
        "backend/native_sessions_lab/test_urls.py",
        "backend/native_sessions_lab/test_http_contract.py",
        "backend/native_sessions_lab/test_http_contract_cases.py",
        "backend/reminders/native_mobile_identity_gate.py",
        "backend/reminders/native_mobile_token_primitives.py",
    ):
        try:
            ast.parse(read(file), filename=file)
        except (SyntaxError, UnicodeError) as exc:
            failures.append(f"{file}: {type(exc).__name__}")

    print(f"N1_STATIC_GATE_RESULT={'FAIL' if failures else 'OK'}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(verify())
