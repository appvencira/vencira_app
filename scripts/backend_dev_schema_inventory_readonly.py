#!/usr/bin/env python3
"""Read-only migration inventory for a *future* isolated DEV backend cut.

Compares migration filenames at this checkout to django_migrations records
read from the currently running DEV API. Does not run a migration, touch
credentials, load live customer rows, build images or deploy services.
"""
from __future__ import annotations

import ast
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "backend/reminders/migrations"
CONTAINER = "vencira_localcheck-api-1"
EXPECTED_PROJECT = "vencira_localcheck"
VALID_NAME = re.compile(r"^\d{4}_[a-zA-Z0-9_]+$")

READ_MIGRATIONS = (
    "from django.db.migrations.recorder import MigrationRecorder; "
    "print('\\n'.join(sorted(n for a,n in "
    "MigrationRecorder.Migration.objects.values_list('app','name') "
    "if a=='reminders')))"
)


def docker(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["sudo", "docker", *args], capture_output=True, text=True, timeout=55,
        check=False,
    )


def main() -> int:
    if not MIGRATIONS.is_dir():
        print("BACKEND_DEV_MIGRATION_SOURCE=ABSENT")
        return 2
    source = set()
    for file in sorted(MIGRATIONS.glob("*.py")):
        if VALID_NAME.fullmatch(file.stem):
            try:
                ast.parse(file.read_text(encoding="utf-8"), filename=str(file))
            except SyntaxError:
                print("BACKEND_DEV_MIGRATION_PY_PARSE=FAIL")
                return 3
            source.add(file.stem)
    if not source:
        print("BACKEND_DEV_MIGRATION_SOURCE=EMPTY")
        return 3
    project = docker("inspect", "-f",
                     '{{index .Config.Labels "com.docker.compose.project"}}',
                     CONTAINER)
    health = docker("inspect", "-f",
                    "{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}",
                    CONTAINER)
    if (project.returncode or project.stdout.strip() != EXPECTED_PROJECT
            or health.returncode or health.stdout.strip() != "healthy"):
        print("BACKEND_DEV_LIVE_API_IDENTITY=FAIL")
        return 4
    deployed = docker("exec", CONTAINER, "python", "manage.py",
                      "shell", "-c", READ_MIGRATIONS)
    if deployed.returncode:
        print("BACKEND_DEV_MIGRATION_READ=FAIL")
        return 5
    # django shell may emit initialization notices; only migration names
    live = {line.strip() for line in deployed.stdout.splitlines()
            if VALID_NAME.fullmatch(line.strip())}
    if not live:
        print("BACKEND_DEV_MIGRATION_LIVE=EMPTY")
        return 6
    missing = sorted(source - live)
    extra = sorted(live - source)
    print("BACKEND_DEV_SOURCE_MIGRATION_COUNT=" + str(len(source)))
    print("BACKEND_DEV_APPLIED_MIGRATION_COUNT=" + str(len(live)))
    print("BACKEND_DEV_NEW_MIGRATIONS=" + str(len(missing)))
    for name in missing:
        print("BACKEND_DEV_NEW_MIGRATION=" + name)
    print("BACKEND_DEV_LIVE_NOT_IN_SOURCE=" + str(len(extra)))
    for name in extra:
        print("BACKEND_DEV_LIVE_ONLY_MIGRATION=" + name)
    print("BACKEND_DEV_SCHEMA_PARITY=" +
          ("YES" if not missing and not extra else "NO"))
    print("BACKEND_DEV_MIGRATIONS_EXECUTED=NO")
    print("BACKEND_DEV_DEPLOY_EXECUTED=NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
