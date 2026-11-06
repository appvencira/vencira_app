#!/usr/bin/env python3
"""I2: main integration gate, read-only, stdlib-only, no deployment."""
from pathlib import Path
import ast
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CORE = (
    "backend/reminders/legal_deadlines.py",
    "backend/reminders/default_reminders.py",
    "backend/reminders/reminder_planning.py",
)
MAIN_EXCLUSIVE = (
    "clients/flutter/lib/ui/control_assessment_card.dart",
    "scripts/c2_deploy_readiness_readonly.sh",
)
FOUNDATION = (
    "backend/manage.py",
    "backend/config/settings.py",
    "backend/config/urls.py",
    "backend/requirements.txt",
    "clients/flutter/pubspec.yaml",
    "clients/flutter/lib/main.dart",
)


def gate(root=ROOT, run_tests=True):
    failed = []
    for name in CORE + MAIN_EXCLUSIVE:
        path = root / name
        ok = path.is_file()
        print(f"I2_PRESERVE_{name}={'OK' if ok else 'MISSING'}")
        if not ok:
            failed.append(name)
        if ok and name.endswith(".py"):
            try:
                ast.parse(path.read_text(encoding="utf-8"), filename=name)
            except (SyntaxError, UnicodeError):
                failed.append(f"invalid:{name}")

    present = {name: (root / name).is_file() for name in FOUNDATION}
    for name, ok in present.items():
        print(f"I2_FOUNDATION_{name}={'PRESENT' if ok else 'PENDING'}")
    if any(present.values()) and not all(present.values()):
        # Partial scaffold is explicitly allowed in main, never claim it runnable.
        print("I2_FOUNDATION_READY=PARTIAL_NOT_RUNNABLE")
    elif all(present.values()):
        print("I2_FOUNDATION_READY=FILES_PRESENT_UNVERIFIED")
    else:
        print("I2_FOUNDATION_READY=NOT_YET_PORTED")

    if run_tests and not failed:
        test = root / "scripts/test_i1_calendar_core.py"
        if not test.is_file():
            failed.append("missing:i1_unit_tests")
        else:
            completed = subprocess.run(
                [sys.executable, str(test)], cwd=str(root), check=False,
            )
            print(f"I2_I1_CORE_REGRESSION={completed.returncode}")
            if completed.returncode:
                failed.append("i1_core_regression")
    print(f"I2_MAIN_FOUNDATION_GATE={'PASS' if not failed else 'FAIL'}")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(gate())
