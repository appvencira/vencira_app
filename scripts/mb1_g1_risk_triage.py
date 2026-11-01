"""G1 static writer triage. Heuristic, no runtime authority."""
import argparse
import ast
from collections import Counter
from pathlib import Path
try:
    from .mb1_g1_source_writer_inventory import analyze_source
except ImportError:
    from mb1_g1_source_writer_inventory import analyze_source

def classify(path):
    parts=path.parts
    name=path.name
    if ("tests" in parts or "test" in parts or name.startswith("test_")
        or "_test" in name):
        return "TEST"
    if name.startswith("offline_") or "lab" in name or "rehears" in name:
        return "LAB"
    if "migrations" in parts:
        return "MIGRATION"
    return "RUNTIME_CANDIDATE"

def triage(root):
    root=Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("G1_ROOT_INVALID")
    counts=Counter()
    errors=0
    files=0
    for p in sorted(root.rglob("*.py")):
        if p.is_symlink():
            errors+=1
            continue
        try:
            hits=analyze_source(p.read_text(encoding="utf-8"))
        except (OSError,UnicodeError,SyntaxError,ValueError):
            errors+=1
            continue
        files+=1
        group=classify(p.relative_to(root))
        for _,kind,name in hits:
            counts[(group,kind)]+=1
            if kind=="WRITE_CANDIDATE" and name in ("execute","executemany","commit","rollback"):
                counts[(group,"SQL_REVIEW")]+=1
            if kind=="WRITE_CANDIDATE" and name in ("put_quarantine","discard_quarantine","write_bytes","unlink","rename","replace"):
                counts[(group,"FS_REVIEW")]+=1
    return files,errors,counts

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",default="backend")
    args=parser.parse_args()
    files,errors,counts=triage(args.source)
    print(f"MB1_G1_TRIAGE_PYTHON_FILES={files}")
    print(f"MB1_G1_TRIAGE_ERRORS={errors}")
    for group in ("RUNTIME_CANDIDATE","MIGRATION","LAB","TEST"):
        for kind in ("WRITE_CANDIDATE","DYNAMIC_REVIEW","SQL_REVIEW","FS_REVIEW"):
            print(f"MB1_G1_{group}_{kind}={counts[(group,kind)]}")
    print("MB1_G1_TRIAGE_SCOPE=HEURISTIC_PATH_CLASSIFICATION")
    print("MB1_G1_RUNTIME_PROVEN=NO")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 1 if errors else 0

if __name__=="__main__":
    raise SystemExit(main())
