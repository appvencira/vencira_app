#!/usr/bin/env python3
"""Read-only MFA transaction lock-order report; not a release gate.

Lists syntactically ordered select_for_update calls in functions.
No imports from app, no database access, no credential processing.
"""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "backend" / "reminders"
TARGETS = (
    "mfa_enrollment.py",
    "mfa_store.py",
    "mfa_session_revocation.py",
    "mfa_factor_rotation.py",
    "mfa_admin_recovery_service.py",
)


def lock_calls(source):
    tree = ast.parse(source)
    results = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            continue
        hits = []
        for item in ast.walk(node):
            if isinstance(item, ast.Call) and isinstance(item.func, ast.Attribute):
                if item.func.attr == "select_for_update":
                    hits.append(item.lineno)
        if hits:
            results.append((node.name, tuple(sorted(hits))))
    return sorted(results)


def main():
    total = 0
    for name in TARGETS:
        path = ROOT / name
        if not path.is_file():
            raise SystemExit("G14_D9_MISSING_SOURCE=" + name)
        for func, lines in lock_calls(path.read_text(encoding="utf-8")):
            for line in lines:
                print(f"G14_D9_LOCK_SITE={name}:{func}:{line}")
                total += 1
    print(f"G14_D9_LOCK_SITES={total}")
    print("G14_D9_LOCK_REPORT=READ_ONLY_REVIEW_REQUIRED")


if __name__ == "__main__":
    main()
