#!/usr/bin/env bash
# Tree-to-tree semantic scope: compare the CURRENT file content, not historical PR changes.
# Read-only: no checkout, merge, write, build, deployment or migration.
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
python3 - <<'PY'
import subprocess

MAIN="origin/main"
FEAT="origin/feature/m3-android-local-notifications"
def git(*args):
    return subprocess.check_output(["git", *args])
for ref in (MAIN, FEAT):
    git("rev-parse", "--verify", ref+"^{commit}")
raw = git("diff", "--name-status", "-z", MAIN, FEAT)
items = raw.split(b"\0")
changes=[]
i=0
while i < len(items) and items[i]:
    status=items[i].decode()
    i+=1
    if status.startswith(("R","C")):
        old=items[i].decode("utf8","replace"); i+=1
        new=items[i].decode("utf8","replace"); i+=1
        changes.append((status,new))
    else:
        path=items[i].decode("utf8","replace"); i+=1
        changes.append((status,path))
def category(path):
    if "/migrations/" in path: return "MIGRATION"
    if path.startswith("backend/"): return "BACKEND"
    if path.startswith("clients/flutter/lib/"): return "FLUTTER_CODE"
    if path.startswith("clients/flutter/test/"): return "FLUTTER_TEST"
    if path.startswith("clients/flutter/"): return "FLUTTER_OTHER"
    if path.startswith((".github/","scripts/")): return "CI_SCRIPTS"
    if path.startswith("compose") or path in (".env.example",".dockerignore",".gitignore"): return "OPERATIONS"
    if path.startswith("docs/") or path.endswith(".md"): return "DOCS"
    return "OTHER"
buckets={}
for status,path in changes:
    buckets.setdefault(category(path),[]).append((status,path))
print("TREE_SCOPE_MAIN="+git("rev-parse",MAIN).decode().strip())
print("TREE_SCOPE_FEATURE="+git("rev-parse",FEAT).decode().strip())
print("TREE_SCOPE_CHANGED_TOTAL="+str(len(changes)))
for area in ("MIGRATION","BACKEND","FLUTTER_CODE","FLUTTER_TEST","FLUTTER_OTHER","CI_SCRIPTS","OPERATIONS","DOCS","OTHER"):
    rows=buckets.get(area,[])
    print(f"TREE_SCOPE_{area}={len(rows)}")
    if area in ("MIGRATION","BACKEND","FLUTTER_CODE","FLUTTER_TEST","FLUTTER_OTHER","OPERATIONS"):
        for status,path in rows[:18]:
            print(f"TREE_DIFF_{area}={status}:{path}")
print("TREE_SCOPE_READONLY=YES")
print("TREE_SCOPE_MERGE_AUTHORIZED=NO")
print("TREE_SCOPE_DEPLOY_AUTHORIZED=NO")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
