#!/usr/bin/env python3
"""G14-E2: fail-closed source guard against using E1's boolean as an issuer grant.

E1 returns only a bool after its own transaction. Until a reviewed trusted
issuer is implemented, non-test backend code may not call or import it. This
AST inventory is intentionally incomplete for dynamic/reflection flows.
No credentials, Django setup, database or network required.
"""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "backend"
VERIFIER = "verify_candidate_password_and_totp"
MODULE = "g14_e1_locked_mfa_verifier"


def e1_references(source):
    tree = ast.parse(source)
    aliases = set()
    module_aliases = set()
    hits = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module:
            if node.module.endswith(MODULE):
                for alias in node.names:
                    if alias.name == VERIFIER or alias.name == "*":
                        hits.add(node.lineno)  # Even importing a bool proof is reviewable.
                        if alias.name == VERIFIER:
                            aliases.add(alias.asname or alias.name)
        elif isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.endswith(MODULE):
                    module_aliases.add(alias.asname or alias.name.split(".")[-1])
                    hits.add(node.lineno)
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and node.id in aliases:
            hits.add(node.lineno)
        if (isinstance(node, ast.Attribute) and node.attr == VERIFIER
                and isinstance(node.value, ast.Name)
                and node.value.id in module_aliases):
            hits.add(node.lineno)
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "getattr" and len(node.args) >= 2
                and isinstance(node.args[0], ast.Name)
                and node.args[0].id in module_aliases
                and isinstance(node.args[1], ast.Constant)
                and node.args[1].value == VERIFIER):
            hits.add(node.lineno)
    return sorted(hits)


def audit_tree(root=ROOT):
    violations = []
    for path in sorted(root.rglob("*.py")):
        if any(part in {"migrations", "__pycache__"} for part in path.parts):
            continue
        if path.name.startswith("test_") or path.name.endswith("_test.py"):
            continue
        relative = path.relative_to(root).as_posix()
        if relative == "native_mobile_service/g14_e1_locked_mfa_verifier.py":
            continue
        for line in e1_references(path.read_text(encoding="utf-8")):
            violations.append((relative, line))
    return violations


def main():
    violations = audit_tree()
    print(f"G14_E2_E1_BOOL_CROSS_BOUNDARY={len(violations)}")
    for path, line in violations:
        print(f"G14_E2_E1_BOOL_REFERENCE={path}:{line}")
    print("G14_E2_BOOL_FENCE=PASS" if not violations else "G14_E2_BOOL_FENCE=FAIL")
    print("G14_E2_TRUSTED_ISSUER_IMPLEMENTED=NO")
    return 0 if not violations else 1


if __name__ == "__main__":
    raise SystemExit(main())
