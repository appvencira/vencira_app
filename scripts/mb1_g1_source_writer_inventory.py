"""Static source inventory, not proof of universal writer coverage."""
import ast
import argparse
import json
from collections import Counter
from pathlib import Path

MUTATION = {"create", "bulk_create", "update", "bulk_update", "delete",
            "get_or_create", "update_or_create", "save", "save_base",
            "execute", "executemany", "commit", "rollback", "put_quarantine",
            "discard_quarantine", "write_bytes", "write_text", "unlink",
            "rename", "replace", "makedirs", "mkdir", "rmtree", "remove",
            "dump", "copy", "copyfile"}
DYNAMIC = {"eval", "exec", "getattr", "setattr", "subprocess", "system",
           "popen", "Popen", "run", "call"}

def analyze_source(source):
    root=ast.parse(source)
    hits=[]
    for node in ast.walk(root):
        if not isinstance(node, ast.Call):
            continue
        target=node.func
        if isinstance(target, ast.Attribute):
            name=target.attr
        elif isinstance(target, ast.Name):
            name=target.id
        else:
            name="INDIRECT_CALL"
        kind="WRITE_CANDIDATE" if name in MUTATION else ("DYNAMIC_REVIEW" if name in DYNAMIC or name=="INDIRECT_CALL" else None)
        if kind:
            hits.append((node.lineno,kind,name))
    return sorted(hits)

def inventory(root):
    root=Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("SOURCE_ROOT_INVALID")
    report={"python_files":0,"parse_errors":0,"write_candidates":0,
            "dynamic_reviews":0,"unreadable_files":0,"unresolved":True,
            "files_with_hits":0}
    for p in sorted(root.rglob("*.py")):
        if p.is_symlink():
            report["unreadable_files"]+=1
            continue
        try:
            hits=analyze_source(p.read_text(encoding="utf-8"))
        except (SyntaxError, UnicodeError, OSError,ValueError):
            report["parse_errors"]+=1
            continue
        report["python_files"]+=1
        report["files_with_hits"]+=bool(hits)
        c=Counter(x[1] for x in hits)
        report["write_candidates"]+=c["WRITE_CANDIDATE"]
        report["dynamic_reviews"]+=c["DYNAMIC_REVIEW"]
    return report

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",default="backend")
    args=parser.parse_args()
    r=inventory(args.source)
    for name,value in r.items():
        print("MB1_G1_"+name.upper()+"="+str(value).upper())
    print("MB1_G1_STATIC_COVERAGE=HEURISTIC_ONLY")
    print("MB1_G1_SCHEDULERS_AND_EXTERNAL_WRITERS=NOT_COVERED")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 1 if r["parse_errors"] or r["unreadable_files"] else 0

if __name__=="__main__":
    raise SystemExit(main())
