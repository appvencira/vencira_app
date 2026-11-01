"""Repository-wide conservative callsite inventory for private attachment storage."""
import argparse
import ast
from pathlib import Path
from collections import Counter

TARGETS={"PrivateQuarantineStore","put_quarantine","discard_quarantine","read_quarantine_for_scanner_only"}
def inventory(root):
    root=Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("INVALID_REPOSITORY")
    found=[];errors=0;files=0
    for p in sorted(root.rglob("*.py")):
        if any(part in {".git",".venv","venv","node_modules"} for part in p.parts):
            continue
        if p.is_symlink():
            errors+=1;continue
        try:
            tree=ast.parse(p.read_text(encoding="utf-8"))
        except (OSError,UnicodeError,SyntaxError):
            errors+=1;continue
        files+=1
        for node in ast.walk(tree):
            if isinstance(node,ast.Call):
                fn=node.func
                name=fn.attr if isinstance(fn,ast.Attribute) else fn.id if isinstance(fn,ast.Name) else ""
                kind="CALL"
            elif isinstance(node,(ast.Import,ast.ImportFrom)):
                names=[a.name for a in node.names]
                name=next((x for x in names if any(t in x for t in TARGETS)),"")
                kind="IMPORT"
            else:
                continue
            if name in TARGETS or any(t in name for t in TARGETS):
                rel=p.relative_to(root).as_posix()
                category=("TEST" if p.name.startswith("test_") or "/tests/" in "/"+rel+"/"
                          else "LAB" if p.name.startswith("offline_") or "rehears" in rel
                          else "RUNTIME_OR_UNKNOWN")
                found.append((rel,node.lineno,name,kind,category))
    return files,errors,found

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",default=".")
    args=ap.parse_args()
    files,errors,items=inventory(args.source)
    print("MB1_G1_STORE_FILES_PARSED="+str(files))
    print("MB1_G1_STORE_SOURCE_ERRORS="+str(errors))
    print("MB1_G1_STORE_MATCHES="+str(len(items)))
    for key,n in sorted(Counter(x[4] for x in items).items()):
        print("MB1_G1_STORE_"+key+"="+str(n))
    print("MB1_G1_STORE_CALLSITES_START")
    for path,line,name,kind,category in items:
        print(f"{category} | {path}:{line} | {kind} | {name}")
    print("MB1_G1_STORE_CALLSITES_END")
    print("MB1_G1_STATIC_COVERAGE=INCOMPLETE_NON_PYTHON_AND_DYNAMIC")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 1 if errors else 0

if __name__=="__main__":
    raise SystemExit(main())
