#!/usr/bin/env python3
"""G14 read-only inventory of MFA state mutations and lock acquisition.

This reports candidate writes, NOT a proof that all dynamic writers were found.
It neither imports Django nor connects to a database. Never prints secrets.
"""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "backend"
MFA_NAMES = (
    "UserMfaState", "UserMfaRecoveryCode",
    "UserMfaPendingRotationCode", "MfaAdministrativeRecoveryCase",
)
MUTATORS = frozenset((
    "save", "delete", "update", "create", "bulk_create", "bulk_update",
    "get_or_create", "update_or_create", "select_for_update",
))
FIELDS = frozenset((
    "enabled", "session_epoch", "encrypted_totp_secret",
    "pending_rotation_secret", "pending_administrative_case_id",
    "last_accepted_counter", "locked_until", "failed_attempts",
))


def find_candidates(path):
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    lines = source.splitlines()
    hits = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            line = node.lineno
            statement = lines[line - 1].strip()
            # The named model is sometimes on a separate line of the chain,
            # so inspect a bounded number of source lines above the call.
            context = " ".join(lines[max(0, line - 5):line])
            if node.func.attr in MUTATORS and any(
                name in context for name in MFA_NAMES
            ):
                hits.add((line, "model_" + node.func.attr))
            elif node.func.attr in ("select_for_update", "save", "update"):
                if "mfa" in path.name or "recovery" in path.name:
                    hits.add((line, "mfa_module_" + node.func.attr))
        if isinstance(node, (ast.Assign, ast.AugAssign, ast.AnnAssign)):
            text = ast.get_source_segment(source, node) or ""
            if any(("." + field) in text for field in FIELDS):
                hits.add((node.lineno, "mfa_field_assignment"))
    return sorted(hits)


def main():
    count = 0
    files = 0
    for path in sorted(ROOT.rglob("*.py")):
        if any(p in ("migrations", "__pycache__") for p in path.parts):
            continue
        if path.name.startswith("test_") or path.name.endswith("_test.py"):
            continue
        rows = find_candidates(path)
        if rows:
            files += 1
            for line, reason in rows:
                print(f"G14_MFA_WRITE_CANDIDATE={path.relative_to(ROOT)}:{line}:{reason}")
                count += 1
    print(f"G14_MFA_WRITER_FILES={files}")
    print(f"G14_MFA_WRITER_CANDIDATES={count}")
    print("G14_MFA_WRITER_INVENTORY=REPORT_ONLY_NOT_A_SECURITY_GATE")


if __name__ == "__main__":
    main()
