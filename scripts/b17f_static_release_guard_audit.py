#!/usr/bin/env python3
"""B17F: independent, read-only static guard audit. Never executes deployment scripts."""
from pathlib import Path
import argparse
import re
import sys

MODES = {
    "web": {
        "deploy_macro_a_ui_web_guarded.sh",
        "deploy_macro_b_premium_ui_web_guarded.sh",
        "deploy_o8c_spacing_web_only.sh",
        "deploy_o9b3_web_guarded.sh",
    },
    "schema": {
        "deploy_macro_a_0018_guarded.sh",
        "deploy_o8c_0015_guarded.sh",
        "deploy_o9b_0016_guarded.sh",
        "deploy_operativa_o2.sh",
        "deploy_operativa_o3.sh",
    },
}
# For legacy paths not explicitly categorized, require the more conservative API mode.
MUTATION_HINT = re.compile(
    r"\b(?:docker\s+compose|migrate\s+reminders|migrate\s+--noinput|"
    r"up\s+-d|force-recreate|step\s+DEPLOY)\b"
)
SUSPICIOUS = re.compile(r"\b(?:eval|source)\b|\b(?:bash|sh)\s+-c\b")
EXPECTED = {
    "mfa_release_entrypoint.sh": [
        "schema-off|mfa-enable|rollback",
        'block "OPERATIONAL_AUTHORIZATION_REQUIRED"',
        "MFA_RELEASE_AUTHORIZED=NO",
        "NO_DEPLOY_NO_LIVE_MIGRATION=1",
    ],
    "mfa_legacy_deploy_guard_readonly.sh": [
        "api|schema) block LEGACY_API_OR_SCHEMA_DEPLOY_DISABLED",
        "test \"$migration\" = 0018_draft_reasons",
    ],
}
def audit(root: Path):
    scripts = root / "scripts"
    findings = []
    deploys = sorted(scripts.glob("deploy_*.sh"))
    if not deploys:
        findings.append("no legacy deploy scripts found")
    names = {p.name for p in deploys}
    for group, members in MODES.items():
        for missing in sorted(members - names):
            findings.append(f"expected {group} script missing: {missing}")
    for p in deploys:
        source = p.read_text(encoding="utf-8")
        mode = ("web" if p.name in MODES["web"] else
                "schema" if p.name in MODES["schema"] else "api")
        marker = "bash scripts/mfa_legacy_deploy_guard_readonly.sh " + mode
        if source.count(marker) != 1:
            findings.append(f"{p.name}: missing/duplicate {mode} guard")
            continue
        before = source.split(marker, 1)[0]
        if MUTATION_HINT.search(before):
            findings.append(f"{p.name}: potential mutation before guard")
        if SUSPICIOUS.search(before):
            findings.append(f"{p.name}: dynamic execution before guard; manual review")
    for name, requirements in EXPECTED.items():
        p = scripts / name
        if not p.is_file():
            findings.append(f"missing {name}")
            continue
        body = p.read_text(encoding="utf-8")
        for token in requirements:
            if token not in body:
                findings.append(f"{name}: missing invariant {token!r}")
    return len(deploys), findings

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    count, findings = audit(args.repo.resolve())
    print(f"B17F_LEGACY_INVENTORY={count}")
    for item in findings:
        print(f"B17F_FINDING={item}")
    print(f"B17F_STATIC_AUDIT={'BLOCKED' if findings else 'PASS'}")
    print("B17F_RELEASE_AUTHORIZED=NO")
    print("C_FICHA_RELEASE_AUTHORIZED=NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 1 if findings else 0

if __name__ == "__main__":
    sys.exit(main())
