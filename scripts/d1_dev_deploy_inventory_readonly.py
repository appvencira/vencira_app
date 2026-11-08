#!/usr/bin/env python3
"""D1: read-only DEV deployment inventory; never deploys, backs up or migrates.

Run on the VPS from a checkout of main. Docker exec only invokes a Django
SELECT on django_migrations in the existing healthy API container. The output
contains migration identifiers, image IDs and git SHAs, not credentials.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
API = "vencira_localcheck-api-1"
SERVICES = (
    "vencira_localcheck-api-1",
    "vencira_localcheck-db-1",
    "vencira_localcheck-web_preview-1",
)


def command(args, *, timeout=30):
    result = subprocess.run(args, capture_output=True, text=True,
                            timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError("command failed: " + args[0] + " (rc="
                           + str(result.returncode) + ")")
    return result.stdout.strip()


def marker(label, value):
    print(label + "=" + str(value), flush=True)


def inventory_migrations():
    names = set()
    for app_dir in (ROOT / "backend").iterdir():
        directory = app_dir / "migrations"
        if not app_dir.is_dir() or not directory.is_dir():
            continue
        for file in directory.glob("[0-9]*.py"):
            if re.fullmatch(r"\d{4}_[a-zA-Z0-9_]+\.py", file.name):
                names.add((app_dir.name, file.stem))
    return names


def main():
    marker("D1_NO_DEPLOY_NO_LIVE_MIGRATION", 1)
    marker("D1_MFA_RELEASE_AUTHORIZED", "NO")
    marker("D1_READ_ONLY", "YES")
    if not (ROOT / "backend" / "config" / "settings.py").is_file():
        raise RuntimeError("backend missing")
    sha = command(["git", "-C", str(ROOT), "rev-parse", "--verify", "HEAD"])
    marker("D1_MAIN_CHECKOUT_SHA", sha)
    branch = command(["git", "-C", str(ROOT), "branch", "--show-current"])
    marker("D1_CHECKOUT_BRANCH", branch if branch else "DETACHED")
    status = command(["git", "-C", str(ROOT), "status", "--porcelain",
                      "--untracked-files=no"])
    marker("D1_TRACKED_WORKTREE_CLEAN", "YES" if not status else "NO")

    urls = (ROOT / "backend/config/urls.py").read_text()
    settings = (ROOT / "backend/config/settings.py").read_text()
    if ("test_i8k_recovery_urls" in urls
            or "native_mobile_service" in urls
            or 'VENCIRA_NATIVE_BEARER_ENABLED = False' not in settings
            or 'if VENCIRA_ENV != "test":' not in settings):
        raise RuntimeError("candidate feature could be routed/enabled")
    marker("D1_MAIN_TEST_ONLY_CANDIDATE_FENCE", "PASS")

    docker = ["docker"] if os.geteuid() == 0 else ["sudo", "docker"]
    for service in SERVICES:
        inspect = command(docker + [
            "inspect", "--format",
            '{{index .Config.Labels "com.docker.compose.project"}}|'
            '{{.State.Status}}|{{if .State.Health}}'
            '{{.State.Health.Status}}{{else}}none{{end}}|'
            '{{.Image}}|{{.Id}}',
            service,
        ])
        fields = inspect.split("|")
        if len(fields) != 5 or fields[:3] != [
                "vencira_localcheck", "running", "healthy"]:
            raise RuntimeError("DEV service not healthy: " + service)
        marker("D1_DEV_" + service.replace("vencira_localcheck-", "")
               .replace("-1", "").upper() + "_HEALTH", "PASS")
        marker("D1_DEV_" + service.replace("vencira_localcheck-", "")
               .replace("-1", "").upper() + "_IMAGE_ID", fields[3][:24])

    # Django's MigrationRecorder.applied_migrations() reads only the
    # django_migrations table. No migrate/check/DDL is performed.
    probe = (
        "import json;"
        "from django.db.migrations.recorder import MigrationRecorder;"
        "rows=sorted([list(x) for x in "
        "MigrationRecorder.Migration.objects.values_list('app','name')]);"
        "print('D1_MIGRATION_JSON='+json.dumps(rows,separators=(',',':')))"
    )
    output = command(docker + [
        "exec", API, "python", "manage.py", "shell", "-c", probe,
    ], timeout=60)
    records = [line[len("D1_MIGRATION_JSON="):]
               for line in output.splitlines()
               if line.startswith("D1_MIGRATION_JSON=")]
    if len(records) != 1:
        raise RuntimeError("no unambiguous read-only migration result")
    applied_raw = json.loads(records[0])
    if not isinstance(applied_raw, list) or not all(
            isinstance(item, list) and len(item) == 2 and all(
                isinstance(part, str) for part in item)
            for item in applied_raw):
        raise RuntimeError("migration recorder returned unexpected data")
    applied = {tuple(record) for record in applied_raw}
    source = inventory_migrations()
    if not source:
        raise RuntimeError("no migrations found in main source")
    source_apps = {app for app, _ in source}
    source_pending = sorted(source - applied)
    source_missing = sorted(
        (app, migration) for app, migration in applied
        if app in source_apps and (app, migration) not in source
    )
    marker("D1_MAIN_MIGRATIONS_DISCOVERED", len(source))
    marker("D1_PERSISTENT_APPLIED_MIGRATIONS_COUNT", len(applied))
    marker("D1_MAIN_NOT_APPLIED_COUNT", len(source_pending))
    marker("D1_APPLIED_NOT_IN_MAIN_COUNT", len(source_missing))
    # Only migration identifiers (never SQL, data, env or credentials).
    for app, name in source_pending:
        marker("D1_MAIN_NOT_APPLIED", app + "." + name)
    for app, name in source_missing:
        marker("D1_APPLIED_NOT_IN_MAIN", app + "." + name)

    marker("D1_BACKUP_RESTORE_VERIFIED", "NO")
    marker("D1_MIGRATION_COMPATIBILITY_VERIFIED", "NO")
    marker("D1_RELEASE_AUTHORIZED", "NO")
    marker("D1_DEPLOY_EXECUTED", "NO")
    marker("D1_LIVE_MIGRATIONS_EXECUTED", "NO")
    marker("D1_PREFLIGHT_INVENTORY_RESULT", 0)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, subprocess.TimeoutExpired,
            OSError, json.JSONDecodeError) as error:
        # No subprocess stdout/stderr, which could disclose live details.
        marker("D1_PREFLIGHT_ERROR_TYPE", type(error).__name__)
        marker("D1_RELEASE_AUTHORIZED", "NO")
        marker("D1_DEPLOY_EXECUTED", "NO")
        marker("D1_LIVE_MIGRATIONS_EXECUTED", "NO")
        marker("D1_PREFLIGHT_INVENTORY_RESULT", 1)
        sys.exit(1)
