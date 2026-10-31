#!/usr/bin/env python3
"""B18K: static call-site audit of high-risk attachment primitives.

Fail closed on newly discovered direct calls outside the reviewed entrypoint.
This is a source gate only, not a runtime sandbox or comprehensive writer freeze.
"""
import ast
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1] / "backend"
TARGETS = {"stage_private_attachment", "record_intent", "put_quarantine",
           "discard_quarantine"}
# Call site scope inspected in GitHub B18J2. Any new direct call must be reviewed.
ALLOWED = {
    ("renewal_attachments/offline_intake.py", "stage_private_attachment"),
    ("reminders/attachment_quarantine_intake.py", "record_intent"),
    ("reminders/attachment_quarantine_intake.py", "put_quarantine"),
    # Intentionally removed: intake must not delete on ambiguous SQL ACK.
    ("renewal_attachments/offline_mb1_pg17_ambiguous_commit_drill.py", "stage_private_attachment"),
    ("renewal_attachments/offline_rejection_recovery.py", "discard_quarantine"),
}
# High-risk path is explicitly forbidden after M1-02 ambiguous-commit fix.
DENIED = {("reminders/attachment_quarantine_intake.py", "discard_quarantine")}
def main():
    found = set()
    errors = []
    for path in ROOT.rglob("*.py"):
        rel = path.relative_to(ROOT).as_posix()
        if "migrations" in path.parts or path.name.startswith("test_") or "/test/" in rel:
            continue
        try:
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=rel)
            for node in ast.walk(tree):
                if not isinstance(node, ast.Call):
                    continue
                name = node.func.attr if isinstance(node.func, ast.Attribute) else (
                    node.func.id if isinstance(node.func, ast.Name) else None)
                if name in TARGETS:
                    found.add((rel, name))
        except (OSError, UnicodeError, SyntaxError) as exc:
            errors.append((rel, str(exc)))
    denied = sorted(found & DENIED)
    unexpected = sorted(found - ALLOWED)
    missing = sorted(ALLOWED - found)
    for rel, name in denied:
        print(f"B18K_FORBIDDEN_DESTRUCTIVE_PATH={rel}:{name}")
    for rel, name in unexpected:
        if (rel, name) not in DENIED:
            print(f"B18K_UNREVIEWED_DIRECT_CALL={rel}:{name}")
    for rel, name in missing:
        print(f"B18K_BASELINE_CALL_MISSING={rel}:{name}")
    print(f"B18K_REVIEWED_CALLSITE_PAIRS={len(found & ALLOWED)}")
    print(f"B18K_UNEXPECTED_CALLSITE_PAIRS={len(unexpected)}")
    print(f"B18K_FORBIDDEN_DESTRUCTIVE_CALLS={len(denied)}")
    print(f"B18K_SOURCE_ERRORS={len(errors)}")
    print("B18K_UNIVERSAL_WRITER_FREEZE=NOT_VERIFIED")
    print("B18K_RELEASE_AUTHORIZED=NO")
    if denied or unexpected or missing or errors:
        print("B18K_STATIC_GATE=FAIL")
        return 1
    print("B18K_STATIC_GATE=OK")
    return 0

if __name__ == "__main__":
    sys.exit(main())
