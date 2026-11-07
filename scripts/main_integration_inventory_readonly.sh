#!/usr/bin/env bash
# Read-only inventory of integration backlog relative to origin/main.
# Does not merge, commit, reset, switch branches, deploy or run migrations.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for x in git python3; do command -v "$x" >/dev/null || exit 2; done
git rev-parse --is-inside-work-tree | grep -qx true
git show-ref --verify --quiet refs/remotes/origin/main || { echo "MAIN_INVENTORY_MAIN_REF_MISSING"; exit 2; }
git show-ref --verify --quiet refs/remotes/origin/feature/m3-android-local-notifications || {
 echo "MAIN_INVENTORY_FEATURE_REF_MISSING"; exit 2; }
BASE="$(git merge-base origin/main origin/feature/m3-android-local-notifications)"
MAIN="$(git rev-parse origin/main)"
FEATURE="$(git rev-parse origin/feature/m3-android-local-notifications)"
echo "MAIN_INVENTORY_MERGE_BASE=$BASE"
echo "MAIN_INVENTORY_MAIN_SHA=$MAIN"
echo "MAIN_INVENTORY_FEATURE_SHA=$FEATURE"
echo "MAIN_INVENTORY_AHEAD=$(git rev-list --count origin/main..origin/feature/m3-android-local-notifications)"
echo "MAIN_INVENTORY_BEHIND=$(git rev-list --count origin/feature/m3-android-local-notifications..origin/main)"
# Full path sets, unlike truncated provider comparison pages.
python3 - "$MAIN" "$FEATURE" <<'PY'
import subprocess, sys
main, feature = sys.argv[1:]
def git(*args):
    return subprocess.check_output(["git", *args], text=True).splitlines()
names = git("diff", "--name-only", "-z", main, feature)
# Python subprocess splitlines is unsuitable for NUL; re-read properly.
raw = subprocess.check_output(["git","diff","--name-only","-z",main,feature])
files = [p.decode("utf-8","replace") for p in raw.split(b"\0") if p]
categories = {
    "MFA_SECURITY": lambda p: "mfa" in p.lower() or "credential" in p.lower() or "session_security" in p.lower(),
    "MIGRATIONS": lambda p: "/migrations/" in p,
    "ATTACHMENTS": lambda p: "attachment" in p.lower(),
    "BACKEND_OTHER": lambda p: p.startswith("backend/"),
    "FLUTTER": lambda p: p.startswith("clients/flutter/"),
    "OPERATIONS": lambda p: p.startswith(("scripts/",".github/","deploy/")) or "docker" in p.lower(),
    "DOCUMENTATION": lambda p: p.startswith("docs/") or p.endswith(".md"),
}
bucket = {k: [] for k in categories}
bucket["OTHER"] = []
for p in files:
    k = next((k for k, pred in categories.items() if pred(p)), "OTHER")
    bucket[k].append(p)
print(f"MAIN_INVENTORY_CHANGED_FILES={len(files)}")
for k, entries in bucket.items():
    print(f"MAIN_INVENTORY_{k}_COUNT={len(entries)}")
    for path in entries[:8]:
        print(f"MAIN_INVENTORY_SAMPLE_{k}={path}")
print("MAIN_INVENTORY_SCOPE=READ_ONLY")
print("MAIN_INVENTORY_MERGE_AUTHORIZED=NO")
print("MAIN_INVENTORY_DEPLOY_AUTHORIZED=NO")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
PY
