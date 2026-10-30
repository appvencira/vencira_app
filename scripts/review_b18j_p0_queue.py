#!/usr/bin/env python3
"""B18J: read-only P0 review queue; classification requires source inspection.

Do not automatically call anything REVIEWED or SAFE based on AST names.
"""
import argparse
import collections
import json
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inventory", type=Path)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.inventory.read_text(encoding="utf-8"))
    if data.get("classification") != "TRIAGED_HEURISTIC_NOT_CENSUS":
        raise SystemExit("B18J_UNTRUSTED_INPUT")
    records = data.get("records")
    if type(records) is not list or len(records) != data.get("candidate_calls"):
        raise SystemExit("B18J_BAD_COUNTS")
    p0 = [r for r in records if r.get("priority") == "P0_REVIEW"]
    if len(p0) != data.get("priorities", {}).get("P0_REVIEW"):
        raise SystemExit("B18J_P0_COUNT_MISMATCH")
    queue = []
    for filename, group in __import__("itertools").groupby(
        sorted(p0, key=lambda x: (x["file"], x["line"], x["call"])),
        key=lambda r: r["file"],
    ):
        rows = list(group)
        queue.append({
            "file": filename, "candidate_calls": len(rows),
            "categories": dict(sorted(collections.Counter(r["category"] for r in rows).items())),
            "review_status": "SOURCE_REVIEW_REQUIRED",
            "proven_capture_coverage": False,
            "calls": [{"line": r["line"], "call": r["call"],
                       "category": r["category"]} for r in rows],
        })
    output = {
        "classification": "P0_SOURCE_REVIEW_QUEUE_ONLY",
        "p0_files": len(queue), "p0_calls": len(p0),
        "source_reviewed": 0, "coverage_verified": False,
        "release_authorized": False, "queue": queue,
    }
    args.output.write_text(json.dumps(output, indent=2, ensure_ascii=False,
                                      sort_keys=True) + "\n", encoding="utf-8")
    print("B18J_P0_FILES=" + str(len(queue)))
    print("B18J_P0_CALLS=" + str(len(p0)))
    print("B18J_SOURCE_REVIEWED=0")
    print("B18J_COVERAGE_VERIFIED=NO")
    print("B18J_RELEASE_AUTHORIZED=NO")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
