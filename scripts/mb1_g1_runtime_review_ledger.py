"""Read-only AST review ledger of G1 runtime writer candidates.

The ledger records source file, line, enclosing function and review category,
not source snippets or credentials. No code is imported or executed.
"""
import argparse
import ast
import csv
from pathlib import Path
from mb1_g1_risk_triage import classify
from mb1_g1_source_writer_inventory import MUTATION, DYNAMIC

SQL = {"execute","executemany","commit","rollback"}
FS = {"put_quarantine","discard_quarantine","write_bytes","write_text",
      "unlink","rename","replace","mkdir","makedirs","rmtree","remove","copyfile"}
ORM = {"create","bulk_create","update","bulk_update","delete","get_or_create",
       "update_or_create","save","save_base"}

def enclosing(scopes, lineno):
    choices=[s for s in scopes if s[0]<=lineno<=s[1]]
    if not choices:
        return "MODULE"
    return min(choices, key=lambda s:s[1]-s[0])[2]

def scan(root):
    root=Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("G1_SOURCE_ROOT_INVALID")
    records=[]
    files=0
    for path in sorted(root.rglob("*.py")):
        if path.is_symlink():
            raise ValueError("G1_SYMLINK_NOT_REVIEWED")
        try:
            tree=ast.parse(path.read_text(encoding="utf-8"))
        except (OSError,UnicodeError,SyntaxError) as exc:
            raise ValueError("G1_PARSE_OR_READ_ERROR") from exc
        files+=1
        if classify(path.relative_to(root))!="RUNTIME_CANDIDATE":
            continue
        scopes=[]
        for n in ast.walk(tree):
            if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef,ast.ClassDef)):
                scopes.append((n.lineno,n.end_lineno,n.name))
        for n in ast.walk(tree):
            if not isinstance(n,ast.Call):
                continue
            fn=n.func
            name=fn.attr if isinstance(fn,ast.Attribute) else (fn.id if isinstance(fn,ast.Name) else "INDIRECT_CALL")
            if name in MUTATION:
                category="SQL_REVIEW" if name in SQL else ("FS_REVIEW" if name in FS else ("ORM_REVIEW" if name in ORM else "OTHER_WRITE_REVIEW"))
            elif name in DYNAMIC or name=="INDIRECT_CALL":
                category="DYNAMIC_REVIEW"
            else:
                continue
            records.append({"path":path.relative_to(root).as_posix(),"line":n.lineno,
                            "scope":enclosing(scopes,n.lineno),"category":category,
                            "call":name,"review_status":"PENDING"})
    return files,sorted(records,key=lambda r:(r["path"],r["line"],r["category"]))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",default="backend")
    ap.add_argument("--out",required=True)
    args=ap.parse_args()
    files,records=scan(args.source)
    output=Path(args.out)
    if output.exists() or output.is_symlink():
        raise ValueError("G1_OUTPUT_MUST_NOT_EXIST")
    fields=("path","line","scope","category","call","review_status")
    with output.open("x",encoding="utf-8",newline="") as fd:
        writer=csv.DictWriter(fd,fieldnames=fields)
        writer.writeheader()
        writer.writerows(records)
    categories={x:sum(r["category"]==x for r in records)
                for x in ("SQL_REVIEW","FS_REVIEW","ORM_REVIEW","OTHER_WRITE_REVIEW","DYNAMIC_REVIEW")}
    print("MB1_G1_LEDGER_FILES_PARSED="+str(files))
    print("MB1_G1_LEDGER_RUNTIME_CALLS="+str(len(records)))
    for key,value in categories.items():
        print("MB1_G1_LEDGER_"+key+"="+str(value))
    print("MB1_G1_LEDGER_ALL_PENDING=YES")
    print("MB1_G1_LEDGER_SEMANTICALLY_REVIEWED=NO")
    print("MB1_G1_LEDGER_CLASSIFICATION=STATIC_HEURISTIC")
    print("MB1_GLOBAL_FREEZE=NOT_VERIFIED")
    print("MB1_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")

if __name__=="__main__":
    main()
