#!/usr/bin/env python3
"""B18I: classify B18H candidate calls without claiming comprehensive coverage."""
import argparse
import collections
import json
from pathlib import Path

HIGH_TOKENS = ("attachment", "journal", "quarantine", "outbox", "recovery", "backup")
def classify(path, call):
    kinds = set(call["kind"])
    name = call["call"]
    if "filesystem" in kinds:
        domain = "filesystem"
    elif "process" in kinds:
        domain = "external_process"
    elif "db" in kinds:
        domain = "database_candidate"
    else:
        domain = "unknown"
    if any(token in path.lower() for token in HIGH_TOKENS):
        priority = "P0_REVIEW"
    elif domain in ("filesystem", "external_process"):
        priority = "P1_REVIEW"
    else:
        priority = "P2_REVIEW"
    return {"file": path, "line": call["line"], "call": name,
            "category": domain, "priority": priority, "status": "UNREVIEWED"}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    raw = json.loads(args.source.read_text(encoding="utf-8"))
    if (raw.get("classification") != "HEURISTIC_ONLY_NOT_COMPLETE"
            or raw.get("errors") or type(raw.get("candidates")) is not list):
        raise SystemExit("B18I_INPUT_UNVERIFIED")
    records = [classify(entry["path"], call)
               for entry in raw["candidates"] for call in entry["calls"]]
    if len(records) != raw["candidate_calls"]:
        raise SystemExit("B18I_COUNT_MISMATCH")
    if not records:
        raise SystemExit("B18I_EMPTY")
    records.sort(key=lambda x: (x["priority"], x["file"], x["line"], x["call"]))
    counts = dict(sorted(collections.Counter(r["priority"] for r in records).items()))
    categories = dict(sorted(collections.Counter(r["category"] for r in records).items()))
    result = {
        "classification": "TRIAGED_HEURISTIC_NOT_CENSUS",
        "candidate_files": raw["candidate_files"],
        "candidate_calls": len(records),
        "priorities": counts,
        "categories": categories,
        "reviewed": 0,
        "remaining": len(records),
        "release_authorized": False,
        "records": records,
    }
    data = json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(data, encoding="utf-8")
    else:
        print(data, end="")
    print("B18I_CANDIDATES=" + str(len(records)))
    print("B18I_P0=" + str(counts.get("P0_REVIEW", 0)))
    print("B18I_P1=" + str(counts.get("P1_REVIEW", 0)))
    print("B18I_P2=" + str(counts.get("P2_REVIEW", 0)))
    print("B18I_REVIEWED=0")
    print("B18I_GLOBAL_FREEZE=NOT_VERIFIED")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
