#!/usr/bin/env python3
"""Fail-closed AST inventory for direct use of the lab-only session issuer.

Only the reviewed non-MFA composition may call the low-level issuer in
non-test backend source. This is a limited syntactic guard, not proof of
trusted identity or protection against dynamic invocation.
"""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "backend"
ISSUER = "issue_verified_candidate_session"
REVIEWED_CALLERS = frozenset({
    "native_mobile_service/g14_d3_candidate_boundary.py",
})


def direct_issuer_calls(source):
    tree = ast.parse(source)
    aliases = {ISSUER}
    module_aliases = {"session_store"}
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module:
            if node.module.endswith("session_store"):
                aliases.update(
                    alias.asname or alias.name
                    for alias in node.names if alias.name == ISSUER
                )
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.endswith("session_store"):
                    module_aliases.add(alias.asname or alias.name.split(".")[0])
    hits = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        target = node.func
        if isinstance(target, ast.Name) and target.id in aliases:
            hits.append(node.lineno)
        elif (isinstance(target, ast.Attribute) and target.attr == ISSUER
              and isinstance(target.value, ast.Name)
              and target.value.id in module_aliases):
            hits.append(node.lineno)
    return sorted(set(hits))


def audit_tree(root=ROOT):
    violations = []
    calls = 0
    for path in sorted(root.rglob("*.py")):
        if any(part in {"migrations", "__pycache__"} for part in path.parts):
            continue
        relative = path.relative_to(root).as_posix()
        if path.name.startswith("test_") or path.name.endswith("_test.py"):
            continue
        lines = direct_issuer_calls(path.read_text(encoding="utf-8"))
        calls += len(lines)
        if lines and relative not in REVIEWED_CALLERS:
            violations.extend((relative, lineno) for lineno in lines)
    return calls, violations


def main():
    calls, violations = audit_tree()
    print(f"G14_TRUSTED_BOUNDARY_DIRECT_CALLS={calls}")
    print(f"G14_TRUSTED_BOUNDARY_UNREVIEWED_CALLS={len(violations)}")
    for path, lineno in violations:
        print(f"G14_TRUSTED_BOUNDARY_UNREVIEWED={path}:{lineno}")
    print("G14_TRUSTED_ISSUER_IMPLEMENTED=NO")
    print("G14_TRUSTED_BOUNDARY_SCAN=PASS" if not violations else
          "G14_TRUSTED_BOUNDARY_SCAN=FAIL")
    return 0 if not violations else 1


if __name__ == "__main__":
    raise SystemExit(main())
