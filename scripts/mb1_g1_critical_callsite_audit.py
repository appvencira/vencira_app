"""Conservative read-only G1 SQL/FS/dynamic triage; never executes target code."""
import argparse
import ast
import csv
from pathlib import Path
try:
    from .mb1_g1_risk_triage import classify
except ImportError:
    from mb1_g1_risk_triage import classify

SQL={"execute","executemany","commit","rollback"}
FS={"put_quarantine","discard_quarantine","write_bytes","write_text","unlink","rename","replace","mkdir","makedirs","rmtree","remove","copyfile"}
DYNAMIC={"eval","exec","getattr","setattr","subprocess","system","popen","Popen","run","call"}

def sql_class(node):
    if not node.args:
        return "SQL_UNKNOWN"
    arg=node.args[0]
    if not isinstance(arg,ast.Constant) or not isinstance(arg.value,str):
        return "SQL_DYNAMIC"
    value=arg.value.lstrip().upper()
    if value.startswith(("SELECT ","WITH ","SHOW ","EXPLAIN ")):
        return "SQL_READ_OR_WRITE_REVIEW"
    if value.startswith(("INSERT ","UPDATE ","DELETE ","ALTER ","DROP ","CREATE ","TRUNCATE ","GRANT ","REVOKE ")):
        return "SQL_MUTATION_CANDIDATE"
    return "SQL_UNKNOWN"

def audit(root):
    root=Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("INVALID_ROOT")
    rows=[]
    for path in sorted(root.rglob("*.py")):
        if path.is_symlink():
            raise ValueError("SYMLINK_IN_SOURCE")
        try:
            tree=ast.parse(path.read_text(encoding="utf-8"))
        except (OSError,UnicodeError,SyntaxError) as e:
            raise ValueError("UNREADABLE_OR_INVALID_SOURCE") from e
        if classify(path.relative_to(root))!="RUNTIME_CANDIDATE":
            continue
        for node in ast.walk(tree):
            if not isinstance(node,ast.Call):
                continue
            f=node.func
            name=f.attr if isinstance(f,ast.Attribute) else (f.id if isinstance(f,ast.Name) else "INDIRECT_CALL")
            if name in SQL:
                category=sql_class(node) if name in ("execute","executemany") else "SQL_TRANSACTION_REVIEW"
            elif name in FS:
                category="FS_SIDE_EFFECT_REVIEW"
            elif name in DYNAMIC or name=="INDIRECT_CALL":
                category="DYNAMIC_EXECUTION_REVIEW"
            else:
                continue
            rows.append((path.relative_to(root).as_posix(),node.lineno,name,category,"PENDING"))
    return sorted(rows)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",default="backend")
    parser.add_argument("--out",required=True)
    args=parser.parse_args()
    output=Path(args.out)
    if output.exists() or output.is_symlink():
        raise ValueError("OUTPUT_EXISTS")
    rows=audit(args.source)
    with output.open("x",encoding="utf-8",newline="") as f:
        writer=csv.writer(f)
        writer.writerow(("path","line","call","classification","review_status"))
        writer.writerows(rows)
    print("MB1_G1_CRITICAL_REVIEW_ROWS="+str(len(rows)))
    for k in ("SQL_DYNAMIC","SQL_MUTATION_CANDIDATE","SQL_READ_OR_WRITE_REVIEW","SQL_UNKNOWN","SQL_TRANSACTION_REVIEW","FS_SIDE_EFFECT_REVIEW","DYNAMIC_EXECUTION_REVIEW"):
        print("MB1_G1_"+k+"="+str(sum(r[3]==k for r in rows)))
    print("MB1_G1_SEMANTIC_REVIEW=NOT_COMPLETED")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")

if __name__=="__main__":
    main()
