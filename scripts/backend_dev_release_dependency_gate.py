#!/usr/bin/env python3
"""Fail-closed release-dependency gate for the DEV backend cut.

Reads source migration dependency declarations through Python AST; does not
execute migration modules, query the database, build an image or deploy.
It deliberately does not try to bypass MFA migrations for attachments.
"""
from __future__ import annotations

import ast
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "backend/reminders/migrations"
MFA_START = "0019_user_mfa_state"
ATTACHMENT = "0027_renewal_attachment_metadata"
BASELINE = "0018_draft_reasons"
NAMED = re.compile(r"^\d{4}_[a-zA-Z0-9_]+$")


def get_local_dependencies(file: Path) -> set[str]:
    node = ast.parse(file.read_text(encoding="utf-8"), filename=str(file))
    cls = next(
        (part for part in node.body
         if isinstance(part, ast.ClassDef) and part.name == "Migration"),
        None,
    )
    if cls is None:
        raise ValueError(f"No Migration class: {file.name}")
    assign = next(
        (a for a in cls.body
         if isinstance(a, ast.Assign) and any(
             isinstance(t, ast.Name) and t.id == "dependencies"
             for t in a.targets)),
        None,
    )
    if assign is None or not isinstance(assign.value, (ast.List, ast.Tuple)):
        raise ValueError(f"Nonliteral dependency list: {file.name}")
    out: set[str] = set()
    for dep in assign.value.elts:
        if isinstance(dep, ast.Tuple) and len(dep.elts) == 2:
            app, name = dep.elts
            if isinstance(app, ast.Constant) and app.value == "reminders":
                if not isinstance(name, ast.Constant) or not isinstance(name.value, str):
                    raise ValueError(f"Dynamic local dependency: {file.name}")
                out.add(name.value)
            elif isinstance(app, ast.Constant):
                # other app dependency
                pass
            else:
                # swappable_dependency(settings.AUTH_USER_MODEL)
                if not (isinstance(app, ast.Call) and
                        isinstance(app.func, ast.Attribute) and
                        app.func.attr == "swappable_dependency"):
                    raise ValueError(f"Unexpected dependency expression: {file.name}")
        elif isinstance(dep, ast.Call) and isinstance(dep.func, ast.Attribute):
            if dep.func.attr != "swappable_dependency":
                raise ValueError(f"Unexpected dependency call: {file.name}")
        else:
            raise ValueError(f"Unexpected dependency: {file.name}")
    return out


def main() -> int:
    files = {p.stem: p for p in DIR.glob("*.py") if NAMED.fullmatch(p.stem)}
    for key in (BASELINE, MFA_START, ATTACHMENT):
        if key not in files:
            print(f"BACKEND_DEV_REQUIRED_MIGRATION_MISSING={key}")
            return 2
    try:
        graph = {name: get_local_dependencies(path) for name, path in files.items()}
        missing = sorted({d for dependencies in graph.values()
                          for d in dependencies if d not in graph})
        if missing:
            print("BACKEND_DEV_BROKEN_DEPENDENCIES=" + ",".join(missing))
            return 3
        touched = set()
        visiting = set()

        def dependencies(name: str) -> None:
            if name in visiting:
                raise ValueError("Cycle in migration graph")
            if name in touched:
                return
            visiting.add(name)
            for parent in graph[name]:
                dependencies(parent)
            visiting.remove(name)
            touched.add(name)

        dependencies(ATTACHMENT)
    except (SyntaxError, OSError, ValueError) as exc:
        print(f"BACKEND_DEV_DEPENDENCY_GRAPH=FAIL:{type(exc).__name__}")
        return 4
    chain = sorted(name for name in touched if name > BASELINE)
    mfa_chain = sorted(name for name in chain if name != ATTACHMENT)
    print("BACKEND_DEV_ATTACHMENT_MIGRATION=" + ATTACHMENT)
    print("BACKEND_DEV_ATTACHMENT_REQUIRES_POST_BASELINE=" + str(len(chain)))
    for name in chain:
        print("BACKEND_DEV_ATTACHMENT_DEPENDENCY=" + name)
    print("BACKEND_DEV_ATTACHMENT_REQUIRES_MFA_CHAIN=" +
          ("YES" if MFA_START in touched else "NO"))
    print("BACKEND_DEV_MFA_DEPENDENCY_COUNT=" + str(len(mfa_chain)))
    # Never count a dependency path as permission to apply it in DEV.
    print("BACKEND_DEV_ATTACHMENT_MIGRATION_INDEPENDENT=" +
          ("NO" if MFA_START in touched else "YES"))
    print("BACKEND_DEV_RELEASE_MIGRATION_GO=NO")
    print("BACKEND_DEV_API_DEPLOY_EXECUTED=NO")
    print("BACKEND_DEV_LIVE_MIGRATIONS_EXECUTED=NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
