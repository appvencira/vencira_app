#!/usr/bin/env python3
"""Compare candidate Django URL surface to the API currently running in DEV.
Read-only; does not authenticate, query customer data, or modify any service.
This is a ROUTE inventory, not a schema or functional compatibility proof.
"""
from __future__ import annotations

import argparse
import ast
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "backend/reminders/urls.py"
CONFIG = ROOT / "backend/config/urls.py"

# Same path() literals as Django; templates are structural and contain no IDs.
def routes_in_file(path: Path, prefix: str) -> set[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"))
    output: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        if not isinstance(node.func, ast.Name) or node.func.id != "path":
            continue
        if not node.args or not isinstance(node.args[0], ast.Constant):
            continue
        if not isinstance(node.args[0].value, str):
            continue
        route = node.args[0].value
        if route.startswith("admin/"):
            continue
        output.add(prefix + route)
    return output


def candidate_routes() -> set[str]:
    config = routes_in_file(CONFIG, "")
    return (config - {"api/v1/"}) | routes_in_file(APP, "api/v1/")


# Only prints route templates; no SQL or HTTP calls.
DJANGO_READONLY_SCRIPT = (
    "from django.urls import get_resolver, URLPattern, URLResolver\n"
    "def walk(items, prefix=''):\n"
    "    for item in items:\n"
    "        route = prefix + str(item.pattern)\n"
    "        if isinstance(item, URLResolver):\n"
    "            walk(item.url_patterns, route)\n"
    "        elif isinstance(item, URLPattern) and not route.startswith('admin/'):\n"
    "            print('WEB_API_ROUTE=' + route)\n"
    "walk(get_resolver().url_patterns)\n"
)


def live_routes(container: str) -> set[str]:
    # No shell interpolation, no file writes, no database queries.
    command = [
        "sudo", "docker", "exec", "-i", container,
        "python", "manage.py", "shell", "-c", DJANGO_READONLY_SCRIPT,
    ]
    run = subprocess.run(command, capture_output=True, text=True, timeout=55)
    if run.returncode:
        print("WEB_API_READONLY_ENUMERATION=FAIL")
        return set()
    return {
        line.partition("=")[2].strip()
        for line in run.stdout.splitlines()
        if line.startswith("WEB_API_ROUTE=")
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--container", default="vencira_localcheck-api-1")
    args = parser.parse_args()
    expected = candidate_routes()
    deployed = live_routes(args.container)
    if not deployed:
        print("WEB_API_ROUTE_COMPARISON=NOT_VERIFIED")
        return 2
    missing = sorted(expected - deployed)
    extra = sorted(deployed - expected)
    print(f"WEB_API_CANDIDATE_ROUTES={len(expected)}")
    print(f"WEB_API_DEPLOYED_ROUTES={len(deployed)}")
    print(f"WEB_API_CANDIDATE_ROUTES_MISSING_LIVE={len(missing)}")
    for route in missing[:80]:
        print(f"WEB_API_MISSING_LIVE_ROUTE={route}")
    print(f"WEB_API_LIVE_ONLY_ROUTES={len(extra)}")
    for route in extra[:20]:
        print(f"WEB_API_LIVE_ONLY_ROUTE={route}")
    print("WEB_API_ROUTE_COMPARISON=DIFF_FOUND" if missing else
          "WEB_API_ROUTE_COMPARISON=ROUTES_PRESENT")
    print("WEB_API_FUNCTIONAL_COMPATIBILITY=NOT_VERIFIED")
    print("WEB_API_CUSTOMER_DATA_ACCESSED=NO")
    print("WEB_API_DEPLOY_EXECUTED=NO")
    # Route differences are information, not by themselves a deploy authorization.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
