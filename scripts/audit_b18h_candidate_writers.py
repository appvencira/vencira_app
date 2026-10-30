#!/usr/bin/env python3
"""B18H static candidate-writer inventory. Read-only; NOT a complete writer census.

Scans AST of backend Python code to identify likely DB and file writers,
including raw SQL, shell invocation and filesystem operations.
Unknown/dynamic calls can escape this heuristic. Does not authorize capture.
"""
import ast
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1] / "backend"
IGNORED = {"migrations", "__pycache__"}
METHODS = {
    "db": {"save", "delete", "create", "bulk_create", "bulk_update",
           "update", "update_or_create", "get_or_create", "execute",
           "executemany", "raw", "set", "add", "remove", "clear"},
    "filesystem": {"write", "write_bytes", "write_text", "unlink",
                   "rename", "replace", "mkdir", "rmdir", "remove",
                   "fsync", "open", "makedirs"},
    "process": {"run", "Popen", "call", "check_call", "check_output"},
}
SPECIAL = {"transaction.on_commit": "db", "os.open": "filesystem",
           "os.replace": "filesystem", "os.rename": "filesystem",
           "os.unlink": "filesystem", "builtins.open": "filesystem"}
def dotted(node):
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        base = dotted(node.value)
        return base + "." + node.attr if base else node.attr
    return ""

def collect(path):
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    records = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        name = dotted(node.func)
        tail = name.rsplit(".", 1)[-1]
        categories = [k for k, v in METHODS.items() if tail in v]
        if name in SPECIAL and SPECIAL[name] not in categories:
            categories.append(SPECIAL[name])
        if not categories:
            continue
        records.append({"line": node.lineno, "call": name, "kind": categories})
    return records

def main():
    if not ROOT.is_dir():
        raise SystemExit("B18H_NO_BACKEND")
    rows = []
    errors = []
    for path in sorted(ROOT.rglob("*.py")):
        if any(p in IGNORED for p in path.relative_to(ROOT).parts):
            continue
        # Tests are separately recorded: don't confuse test writes with service writers.
        if path.name.startswith("test_") or "/test/" in path.as_posix():
            continue
        try:
            calls = collect(path)
            if calls:
                rows.append({"path": path.relative_to(ROOT).as_posix(), "calls": calls})
        except (SyntaxError, UnicodeError, OSError) as exc:
            errors.append({"path": str(path.relative_to(ROOT)), "error": type(exc).__name__})
    result = {
        "classification": "HEURISTIC_ONLY_NOT_COMPLETE",
        "release_authorized": False,
        "scanned_source": "backend excluding migrations and test files",
        "candidate_files": len(rows),
        "candidate_calls": sum(len(row["calls"]) for row in rows),
        "errors": errors,
        "candidates": rows,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    if errors:
        return 2
    if not rows:
        return 3
    return 0

if __name__ == "__main__":
    sys.exit(main())
