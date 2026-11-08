#!/usr/bin/env python3
"""I8-M release-blocking static inventory, no network, database or Docker.

PASS here means the existing lab remains isolated; it does NOT mean I8-M
end-to-end HTTPS has been validated. Run from any cwd.
"""
from pathlib import Path
import ast

ROOT = Path(__file__).resolve().parents[1]


def source(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition, message):
    if not condition:
        raise SystemExit("MAIN_I8M_STATIC_GUARD=FAIL " + message)


url_config = source("backend/config/urls.py")
recovery_urls = source("backend/native_mobile_service/test_i8k_recovery_urls.py")
tls_server = source("scripts/native_i8k_https_server.py")
http_port = source("clients/flutter/lib/api/native_http_auth_port.dart")
recovery_gateway = source("clients/flutter/lib/api/native_recovery_login_gateway.dart")
backend_settings = source("backend/config/settings.py")
main_dart = source("clients/flutter/lib/main.dart")

for name, code in [
    ("production URLconf", url_config),
    ("recovery URLconf", recovery_urls),
    ("isolated HTTPS bridge", tls_server),
    ("Flutter HTTP port", http_port),
    ("Flutter recovery gateway", recovery_gateway),
    ("backend settings", backend_settings),
    ("Flutter main", main_dart),
]:
    if name.endswith("URLconf") or name in ("isolated HTTPS bridge", "backend settings"):
        ast.parse(code, filename=name)

# Never expose candidate URLconf from the application's main Django routes.
require("test_i8k_recovery_urls" not in url_config,
        "recovery test URLconf reached from operational config.urls")
require("native_recovery_login_gateway.dart" not in main_dart,
        "lab recovery gateway imported by main.dart")
require("VENCIRA_I8K_NETWORK_ISOLATED" in tls_server
        and 'os.getenv("VENCIRA_ENV") == "test"' in tls_server,
        "TLS bridge lost test-only isolated guards")
require("test_i8k_recovery_urls" in tls_server,
        "TLS bridge has unexpected URLconf")
require("VENCIRA_I8K_RECOVERY_LAB" in source(
    "backend/native_mobile_service/test_i8k_recovery_views.py"),
    "recovery lab view missing guard")
require("VENCIRA_NATIVE_BEARER_ENABLED = False" in backend_settings,
        "native bearer default no longer disabled")
require("Recovery requires a separate MFA challenge" in recovery_gateway,
        "recovery gateway may accept password-only issuance")
require("throw const NativeHttpAuthFailure();" in http_port
        and "/api/v1/mobile/auth/recover/mfa/" in http_port,
        "HTTP adapter must fail closed on password-only recovery")

print("MAIN_I8M_LAB_ISOLATION_STATIC=PASS")
print("MAIN_I8M_PASSWORD_ONLY_FENCE_STATIC=PASS")

# A deliberately non-PASS report for known uncovered integration properties:
# The app uses an auth adapter that can request revoke, but the restricted
# I8-K recovery-only URLconf does not register the revocation endpoint.
revoke_path = "/api/v1/mobile/token/revoke/"
if revoke_path in http_port and revoke_path not in recovery_urls:
    print("MAIN_I8M_HTTPS_REVOKE_CONTRACT=NOT_IMPLEMENTED_IN_LAB_URLCONF")
else:
    print("MAIN_I8M_HTTPS_REVOKE_CONTRACT=REVIEW_REQUIRED")

print("MAIN_I8M_REAL_TLS_CLIENT_SERVER=NOT_TESTED")
print("MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED")
print("MFA_RELEASE_AUTHORIZED=NO")
print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
print("MAIN_I8M_STATIC_GATE_RESULT=0")
