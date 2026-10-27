#!/usr/bin/env python3
"""Static check: all historical routes must call the guard before mutation."""
from pathlib import Path
import re
root=Path(__file__).resolve().parent
scripts=sorted(root.glob("deploy_*.sh"))
assert len(scripts)==16, "Unexpected historical deployment inventory"
web={"deploy_macro_a_ui_web_guarded.sh","deploy_macro_b_premium_ui_web_guarded.sh","deploy_o8c_spacing_web_only.sh","deploy_o9b3_web_guarded.sh"}
schema={"deploy_macro_a_0018_guarded.sh","deploy_o8c_0015_guarded.sh","deploy_o9b_0016_guarded.sh","deploy_operativa_o2.sh","deploy_operativa_o3.sh"}
for path in scripts:
    source=path.read_text()
    mode="web" if path.name in web else "schema" if path.name in schema else "api"
    marker="bash scripts/mfa_legacy_deploy_guard_readonly.sh "+mode
    assert source.count(marker)==1, path.name
    prefix=source.split(marker)[0]
    assert not re.search(r"\b(?:docker\s+compose|migrate\s+reminders|up\s+-d|force-recreate|step\s+DEPLOY)\b",prefix), path.name
guard=(root/"mfa_legacy_deploy_guard_readonly.sh").read_text()
assert "api|schema) block LEGACY_API_OR_SCHEMA_DEPLOY_DISABLED" in guard
assert 'test "$migration" = 0018_draft_reasons' in guard
print("MFA_LEGACY_16_GUARDS_STATIC=OK")
print("MFA_LEGACY_API_SCHEMA_FAIL_CLOSED=OK")
print("MFA_WEB_REQUIRES_0018=OK")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
