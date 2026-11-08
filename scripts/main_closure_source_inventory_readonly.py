#!/usr/bin/env python3
"""VENCIRA closure inventory: source-only, no network, Docker or DB writes.

Records native Android entrypoint, implemented Flutter screens, guarded
experimental Django URLs/apps, and migration dependency graph from Python AST.
Not a replacement for runtime/visual tests or a restore/migrate rehearsal.
"""
import ast
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FLUTTER = ROOT / "clients" / "flutter" / "lib"
BACKEND = ROOT / "backend"
SCREENS = {
    "DASHBOARD": "ui/dashboard_screen.dart",
    "CLIENT_RENEWAL_EDITOR": "ui/renewal_editor.dart",
    "RENEWAL_DETAIL": "ui/renewal_detail_screen.dart",
    "CALENDAR_AGENDA": "ui/day_agenda_screen.dart",
    "RENEWAL_ARCHIVE": "ui/renewal_archive_screen.dart",
    "RESULTS": "ui/results_screen.dart",
    "MODALITY_CATALOG": "ui/modality_catalog_screen.dart",
    "INSURER_CATALOG": "ui/insurer_catalog_screen.dart",
    "OPERATIONAL_INBOX": "ui/operational_inbox_screen.dart",
    "MFA_SETUP": "ui/mfa_setup_screen.dart",
}
EXPERIMENTAL = {
    "native_mobile_service",
    "native_sessions_lab",
    "renewal_attachments",
}

def mark(name, value):
    print(f"CLOSE_{name}={value}", flush=True)

def require(value, reason):
    if not value:
        raise RuntimeError(reason)

def extract_dependencies(path):
    """Read literal dependency edges, ignoring reviewed swappable expressions.

    A migrations.swappable_dependency(settings.AUTH_USER_MODEL) is a
    standard dynamic Django edge; it does not invalidate an explicit
    literal reminders predecessor. Dynamic/unknown edges are surfaced
    separately; no Python migration file is imported or executed.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=path.name)
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == "Migration":
            for item in node.body:
                if isinstance(item, ast.Assign) and any(
                        isinstance(target, ast.Name) and
                        target.id == "dependencies" for target in item.targets):
                    if not isinstance(item.value, (ast.List, ast.Tuple)):
                        return None
                    edges = []
                    for dependency in item.value.elts:
                        try:
                            edges.append(ast.literal_eval(dependency))
                        except (ValueError, TypeError):
                            if (isinstance(dependency, ast.Call)
                                and isinstance(dependency.func, ast.Attribute)
                                and dependency.func.attr == "swappable_dependency"
                                and isinstance(dependency.func.value, ast.Name)
                                and dependency.func.value.id == "migrations"):
                                edges.append(("DJANGO_DYNAMIC", "AUTH_USER_MODEL"))
                            else:
                                edges.append(("UNKNOWN_DYNAMIC", "REVIEW_REQUIRED"))
                    return edges
    return None

def main():
    mark("SOURCE_READ_ONLY", "YES")
    mark("MFA_RELEASE_AUTHORIZED", "NO")
    mark("NO_DEPLOY_NO_LIVE_MIGRATION", 1)

    sha = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "--verify", "HEAD"],
        capture_output=True, text=True, timeout=10, check=True).stdout.strip()
    require(re.fullmatch(r"[0-9a-f]{40}", sha) is not None, "invalid sha")
    mark("MAIN_SHA", sha)

    main = (FLUTTER / "main.dart").read_text(encoding="utf-8")
    android = (FLUTTER / "ui/android_web_access_screen.dart").read_text(
        encoding="utf-8")
    urls = (BACKEND / "config/urls.py").read_text(encoding="utf-8")
    settings = (BACKEND / "config/settings.py").read_text(encoding="utf-8")

    require("AndroidWebAccessScreen()" in main, "missing Android safety entry")
    require("LaunchMode.externalApplication" in android,
            "browser boundary changed")
    require("https://dev.vencira.es/" in android,
            "web preview endpoint changed")
    require("NativeMobileRecoveryEntry" not in main and
            "NativeHttpAuthPort" not in main,
            "native test candidate wired in operational main.dart")
    mark("ANDROID_NORMAL_ENTRY", "EXTERNAL_BROWSER_ONLY")
    mark("NATIVE_RECOVERY_WIRED_TO_MAIN", "NO")
    mark("APK_FUNCTIONAL_NATIVE_LOGIN", "NOT_INTEGRATED")

    require("native_mobile_service" not in urls and
            "test_i8k_recovery_urls" not in urls,
            "test-only native HTTP routes exposed in operational URLconf")
    require("VENCIRA_NATIVE_BEARER_ENABLED = False" in settings,
            "native issuer fence changed")
    require('if VENCIRA_ENV != "test":' in settings,
            "missing test environment fence")
    mark("DJANGO_OPERATIONAL_NATIVE_ROUTE_FENCE", "PASS")

    existing = 0
    for name, relative in SCREENS.items():
        if (FLUTTER / relative).is_file():
            mark("FLUTTER_SCREEN_" + name, "SOURCE_PRESENT_NOT_VISUALLY_TESTED")
            existing += 1
        else:
            mark("FLUTTER_SCREEN_" + name, "MISSING")
    mark("FLUTTER_SCREENS_SOURCE_PRESENT", f"{existing}/{len(SCREENS)}")

    migrations = BACKEND / "reminders/migrations"
    pending = []
    dependency_unknown = []
    swappable = []
    for n in range(19, 28):
        files = sorted(migrations.glob(f"{n:04d}_*.py"))
        require(len(files) == 1, f"reminders migration {n} missing/duplicate")
        name = files[0].stem
        dependencies = extract_dependencies(files[0])
        if dependencies is None:
            dependency_unknown.append(name)
            status = "REVIEW_DYNAMIC_DEPENDENCIES"
        else:
            if ("UNKNOWN_DYNAMIC", "REVIEW_REQUIRED") in dependencies:
                dependency_unknown.append(name)
            if ("DJANGO_DYNAMIC", "AUTH_USER_MODEL") in dependencies:
                swappable.append(name)
            references_prev = any(
                isinstance(dep, (list, tuple)) and len(dep) == 2
                and dep[0] == "reminders"
                and isinstance(dep[1], str)
                and dep[1].startswith(f"{n - 1:04d}_")
                for dep in dependencies)
            status = "CHAIN_PREVIOUS_PRESENT" if references_prev else (
                "REVIEW_DEPENDENCIES")
        mark("REMINDERS_MIGRATION", name + ":" + status)
        pending.append(name)
    mark("REMINDERS_0019_0027_FILES", len(pending))
    mark("REMINDERS_UNKNOWN_STATIC_DEPENDENCIES",
         len(dependency_unknown))
    mark("REMINDERS_DJANGO_SWAPPABLE_AUTH_DEPENDENCIES", len(swappable))
    mark("DEV_MIGRATION_PLAN_EXECUTED", "NO")
    mark("O5_BACKUP_RESTORED", "NOT_VERIFIED")
    mark("APK_VISUAL_SMOKE", "NOT_VERIFIED")
    mark("DEPLOY_EXECUTED", "NO")
    mark("LIVE_MIGRATIONS_EXECUTED", "NO")
    mark("PREFLIGHT_RESULT", 0)

if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, SyntaxError, ValueError,
            subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        mark("PREFLIGHT_ERROR_TYPE", type(exc).__name__)
        mark("PREFLIGHT_RESULT", 1)
        sys.exit(1)
