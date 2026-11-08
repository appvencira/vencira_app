#!/usr/bin/env python3
"""Read-only inventory of complete Git tree objects in main and remote branches.

No fetch, merge, checkout, reset, change of refs, deployment or database action.
Run: python3 scripts/main_branch_tree_inventory_readonly.py > /tmp/vencira-trees.json
"""
import argparse
import json
import subprocess
import sys
from collections import Counter


def git(*args):
    return subprocess.check_output(["git", *args], stderr=subprocess.PIPE)


def objects(ref):
    """Return path -> (mode, type, object_sha) using the full tree."""
    result = {}
    for item in git("ls-tree", "-r", "-z", ref).split(b"\0"):
        if not item:
            continue
        metadata, path = item.split(b"\t", 1)
        mode, kind, sha = metadata.decode("ascii").split(" ")
        result[path.decode("utf-8", "surrogateescape")] = (mode, kind, sha)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="refs/remotes/origin/main")
    parser.add_argument("--branch", action="append", default=[],
                        help="Remote ref; repeatable. Default: all origin refs except main/HEAD")
    parser.add_argument("--summary-only", action="store_true")
    args = parser.parse_args()
    try:
        base_sha = git("rev-parse", "--verify", args.base + "^{commit}").decode().strip()
        base_files = objects(args.base)
        branches = args.branch or [
            ref for ref in git("for-each-ref", "--format=%(refname)",
                               "refs/remotes/origin").decode().splitlines()
            if ref not in ("refs/remotes/origin/main", "refs/remotes/origin/HEAD")
        ]
        report = {
            "base_ref": args.base, "base_commit": base_sha,
            "method": "full Git tree object identity (not commit counts)",
            "branches": [],
        }
        for branch in sorted(set(branches)):
            head_sha = git("rev-parse", "--verify", branch + "^{commit}").decode().strip()
            files = objects(branch)
            counts = Counter()
            changes = []
            for path in sorted(base_files.keys() | files.keys()):
                left, right = base_files.get(path), files.get(path)
                if left == right:
                    continue
                status = ("added_in_branch" if left is None else
                          "absent_in_branch" if right is None else "different")
                counts[status] += 1
                if not args.summary_only:
                    changes.append({
                        "path": path, "status": status,
                        "main_object": left[2] if left else None,
                        "branch_object": right[2] if right else None,
                    })
            row = {
                "ref": branch, "commit": head_sha,
                "main_files": len(base_files), "branch_files": len(files),
                "counts": dict(sorted(counts.items())),
                "equal_file_count": len(set(base_files) & set(files)) - counts["different"],
            }
            if not args.summary_only:
                row["changes"] = changes
            report["branches"].append(row)
        print(json.dumps(report, indent=2, ensure_ascii=False))
    except (subprocess.CalledProcessError, OSError, ValueError) as exc:
        print("TREE_INVENTORY_FAILED: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
