#!/usr/bin/env python3
"""Read-only source contract audit: native Flutter bearer client is not a released API.

Scope is intentionally narrow; this is NOT an authentication penetration test,
runtime URL resolution test, nor proof that all Flutter routes are unreachable.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
def read(path):
    return (root / path).read_text(encoding="utf-8")

port = read("clients/flutter/lib/api/native_http_auth_port.dart")
screen = read("clients/flutter/lib/ui/native_login_screen.dart")
main = read("clients/flutter/lib/main.dart")
urls = read("backend/config/urls.py") + "\n" + read("backend/reminders/urls.py")
settings = read("backend/config/settings.py")

routes = set(re.findall(r"_post\('(/api/v1/mobile/[^']+)'", port))
required = {
    "/api/v1/mobile/auth/password/",
    "/api/v1/mobile/auth/mfa/",
    "/api/v1/mobile/auth/recover/password/",
    "/api/v1/mobile/auth/recover/mfa/",
    "/api/v1/mobile/token/refresh/",
    "/api/v1/mobile/token/revoke/",
}
assert required <= routes, "Native client contract changed: review manually"
print("NATIVE_CONTRACT_EXPECTED_CLIENT_PATHS=OK")
assert "class NativeHttpAuthPort" in port
assert "response.headers.containsKey('set-cookie')" in port
assert "class NativeLoginScreen" in screen
assert "NativeLoginScreen(" not in main and "NativeHttpAuthPort(" not in main, (
    "Main.dart now references experimental native login; manual release review required"
)
print("NATIVE_CONTRACT_MAIN_ENTRYPOINT_UNWIRED=OK")
assert "VENCIRA_NATIVE_BEARER_ENABLED = False" in settings
assert 'rest_framework.authentication.SessionAuthentication' in settings
print("NATIVE_CONTRACT_BACKEND_BEARER_DISABLED=OK")
assert not any(route in urls for route in routes), (
    "A native endpoint appears in reviewed URL definitions: audit route exposure"
)
assert "include(" in urls
assert "/api/v1/mobile/" not in urls
print("NATIVE_CONTRACT_REVIEWED_URLS_NO_ISSUER=OK")
print("NATIVE_CONTRACT_WEB_COOKIE_AND_NATIVE_BEARER_DISTINCT=YES")
print("NATIVE_CONTRACT_RELEASE_AUTHORIZED=NO")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
print("NATIVE_CONTRACT_STATIC_AUDIT=PASS")
