#!/usr/bin/env python3
"""I2-B bootstrap source gate (stdlib only). No Django import or database access."""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    "backend/manage.py",
    "backend/config/__init__.py",
    "backend/config/asgi.py",
    "backend/config/wsgi.py",
    "backend/config/views.py",
    "backend/config/settings.py",
    "backend/config/urls.py",
    "backend/reminders/apps.py",
    "backend/reminders/__init__.py",
)
UNRESOLVED = (
    "backend/reminders/mfa_middleware.py",
    "backend/reminders/login_security.py",
    "backend/reminders/mfa_challenge.py",
    "backend/reminders/urls.py",
    "backend/reminders/models.py",
)
REQUIRED_SETTINGS = (
    'if VENCIRA_ENV != "test":',
    'VENCIRA_NATIVE_BEARER_ENABLED = False',
    'INSTALLED_APPS.append("native_sessions_lab")',
    'INSTALLED_APPS.append("native_mobile_service")',
    '"rest_framework.authentication.SessionAuthentication"',
)


def audit(root=ROOT):
    for relative in SOURCES:
        path = root / relative
        if not path.is_file():
            raise AssertionError(f"missing source: {relative}")
        ast.parse(path.read_text(encoding="utf-8"), filename=relative)
    settings = (root / "backend/config/settings.py").read_text(encoding="utf-8")
    for clause in REQUIRED_SETTINGS:
        if clause not in settings:
            raise AssertionError(f"missing guard: {clause}")
    missing = [p for p in UNRESOLVED if not (root / p).is_file()]
    if missing:
        print("I2B_DJANGO_RUNTIME=BLOCKED_INCOMPLETE_DEPENDENCIES")
        for item in missing:
            print(f"I2B_MISSING_DEPENDENCY={item}")
    else:
        print("I2B_DJANGO_RUNTIME=UNVERIFIED_REQUIRES_FULL_GATE")
    print("I2B_BOOTSTRAP_SOURCE=OK")
    print("I2B_DEPLOY_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return missing


if __name__ == "__main__":
    audit()
