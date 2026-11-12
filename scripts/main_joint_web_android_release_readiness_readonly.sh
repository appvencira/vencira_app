#!/usr/bin/env bash
# VENCIRA B: read-only joint web + Android launch readiness inventory.
# This is NOT a release/deploy/authorization command.
set -Eeuo pipefail
set +x
umask 077
mark() { printf 'JOINT_B_%s=%s\n' "$1" "$2"; }
echo 'MFA_RELEASE_AUTHORIZED=NO'
echo 'NO_DEPLOY_NO_LIVE_MIGRATION=1'
mark DEPLOY_EXECUTED NO
mark LIVE_MIGRATIONS_EXECUTED NO
mark LIVE_RESTORE_EXECUTED NO
mark ANDROID_SIGNED NO
mark OPERATIONAL_ISSUER_ENABLED NO
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
head="$(git rev-parse --verify HEAD)"
origin="$(git rev-parse --verify refs/remotes/origin/main)"
if [[ "$head" != "$origin" || -n "$(git status --porcelain)" ]]; then
  mark MAIN_CLEAN FAIL
  exit 2
fi
mark MAIN_CLEAN PASS
python3 - <<'PY'
import ast
from pathlib import Path

root=Path.cwd()
files={
 "operational_urls": "backend/config/urls.py",
 "issuer": "backend/native_mobile_service/native_operational_issuer_gate.py",
 "android": "clients/flutter/lib/main.dart",
 "boundary": "clients/flutter/lib/ui/native_android_startup_boundary.dart",
 "settings": "backend/config/settings.py",
 "d18": "scripts/main_d18_native_auth_release_fence_static.py",
}
for key, path in files.items():
    file=root/path
    assert file.is_file(), f"Missing {path}"
    if path.endswith(".py"):
        ast.parse(file.read_text(), filename=path)
print("JOINT_B_SOURCE_INVENTORY=PASS")
urls=(root/files["operational_urls"]).read_text()
issuer=(root/files["issuer"]).read_text()
main=(root/files["android"]).read_text()
settings=(root/files["settings"]).read_text()
assert "native_mobile_service" not in urls
assert "test_d22_urls" not in urls
assert "test_i8k_recovery_urls" not in urls
assert 'raise NativeIssuerUnavailable("Native mobile issuer unavailable")' in issuer
assert "VENCIRA_NATIVE_BEARER_ENABLED = False" in settings
assert "NativeAndroidStartupBoundary()" in main
assert "NativeLoginScreen(" not in main
print("JOINT_B_PRODUCTION_AUTH_HARD_FENCE=PASS")
print("JOINT_B_REAL_NATIVE_LOGIN_IN_MAIN=NO")
print("JOINT_B_OPERATIONAL_ISSUER_READY=NO")
print("JOINT_B_PRODUCTION_MOBILE_ROUTES=NO")
PY
mark RELEASE_BLOCKERS_VERIFIED PASS
# A zero exit code means the release is SAFELY BLOCKED, never ready for launch.
mark JOINT_RELEASE_AUTHORIZED NO
mark READ_ONLY_PREFLIGHT PASS
mark RESULT 0
