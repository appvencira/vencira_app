#!/usr/bin/env python3
"""B18K P0 review pack: source-backed call context, NO automatic verdicts."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "backend"
ap = argparse.ArgumentParser()
ap.add_argument("queue", type=Path)
ap.add_argument("--output", type=Path, required=True)
args = ap.parse_args()
data = json.loads(args.queue.read_text(encoding="utf-8"))
if data.get("classification") != "P0_SOURCE_REVIEW_QUEUE_ONLY":
    raise SystemExit("B18K_INVALID_QUEUE")
if data.get("p0_calls") != 131 or data.get("p0_files") != 34:
    raise SystemExit("B18K_UNEXPECTED_BASELINE")
lines = ["# B18K — P0 source review pack (unreviewed)", "",
         "All excerpts require human inspection. Lines are not security decisions.", ""]
present = 0
missing = []
for file in data["queue"]:
    relative = file["file"]
    path = (ROOT / relative).resolve()
    if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
        missing.append(relative)
        continue
    source = path.read_text(encoding="utf-8").splitlines()
    lines.extend([f"## {relative} — {file['candidate_calls']} candidate calls", ""])
    for call in file["calls"]:
        number = call["line"]
        begin, end = max(1, number-3), min(len(source), number+3)
        lines.extend([f"### L{number} — `{call['call']}` ({call['category']})",
                      "```python"])
        lines.extend(f"{idx:04d} {source[idx-1]}" for idx in range(begin, end+1))
        lines.extend(["```", "Verdict: UNREVIEWED — caller reachability, guard, side effects and lifecycle pending.", ""])
        present += 1
args.output.write_text("\n".join(lines), encoding="utf-8")
print("B18K_P0_CONTEXTS="+str(present))
print("B18K_MISSING_SOURCE_FILES="+str(len(missing)))
print("B18K_SOURCE_REVIEWED=0")
print("B18K_OPERATIONAL_CAPTURE=BLOCKED")
if missing or present != data["p0_calls"]:
    print("B18K_SOURCE_PACK=FAIL")
    raise SystemExit(1)
print("B18K_SOURCE_PACK=OK")
