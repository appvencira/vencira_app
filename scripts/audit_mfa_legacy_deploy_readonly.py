#!/usr/bin/env python3
"""Inventory only: NOT a deploy authorization, not a proof of runtime safety."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent
legacy = sorted(root.glob("deploy_*.sh"))
print("MFA_LEGACY_DEPLOY_INVENTORY=%d" % len(legacy))
not_protected = []
for path in legacy:
    src = path.read_text(encoding="utf-8")
    invokes_live = bool(re.search(r"\b(?:up\s+-d|force-recreate|migrate\s+reminders|migrate\s+--noinput)\b", src))
    if not invokes_live:
        # Classed as requires manual inspection even if direct commands use variables.
        invokes_live = "docker compose" in src or '"${COMPOSE[@]}"' in src or "step DEPLOY" in src
    guarded = "mfa_deploy_entry_readonly.sh" in src or "mfa_s1_release_readonly.sh" in src
    if invokes_live and not guarded:
        not_protected.append(path.name)
print("MFA_LEGACY_DEPLOY_REQUIRES_REVIEW=%d" % len(not_protected))
for name in not_protected:
    print("REVIEW_SCRIPT=" + name)
print("MFA_AUDIT_ONLY=1")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
