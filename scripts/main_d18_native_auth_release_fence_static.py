#!/usr/bin/env python3
"""D18 deterministic fail-closed readiness audit; never issues credentials."""
import ast
from pathlib import Path

root = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (root / path).read_text(encoding="utf-8")


def require(value: bool, label: str) -> None:
    if not value:
        print(f"D18_{label}=FAIL", flush=True)
        raise SystemExit(3)
    print(f"D18_{label}=PASS", flush=True)


urls = source("backend/config/urls.py")
settings = source("backend/config/settings.py")
client = source("clients/flutter/lib/main.dart")
native = source("clients/flutter/lib/ui/native_android_startup_boundary.dart")
auth = source("clients/flutter/lib/api/native_http_auth_port.dart")
first = source("clients/flutter/lib/api/native_first_issuance_entry.dart")
recovery = source("clients/flutter/lib/api/native_recovery_login_gateway.dart")
public_gate = source("clients/flutter/lib/ui/android_web_access_screen.dart")
test_url_1 = source("backend/native_mobile_service/test_i8d_urls.py")
test_url_2 = source("backend/native_mobile_service/test_i8k_recovery_urls.py")

for name, data in (
    ("backend/config/urls.py", urls),
    ("backend/config/settings.py", settings),
    ("backend/native_mobile_service/test_i8d_urls.py", test_url_1),
    ("backend/native_mobile_service/test_i8k_recovery_urls.py", test_url_2),
):
    ast.parse(data, filename=name)
require(
    "test_i8d_urls" not in urls and "test_i8k_recovery_urls" not in urls
    and "native_mobile_service" not in urls
    and 'include("reminders.urls")' in urls,
    "OPERATIONAL_URLCONF_LAB_ABSENT",
)
require(
    "VENCIRA_NATIVE_BEARER_ENABLED = False" in settings
    and 'if VENCIRA_ENV != "test":' in settings
    and 'INSTALLED_APPS.append("native_mobile_service")' in settings,
    "NATIVE_BEARER_PRODUCTION_OFF",
)
require(
    "NativeAndroidStartupBoundary()" in client
    and "NativeLabLoginShell" in client
    and "!kReleaseMode" in client
    and "NativeLoginScreen(" not in client
    and "NativeHttpAuthPort(" not in client
    and "NativeFirstIssuanceEntry(" not in client,
    "REAL_ANDROID_ISSUER_UNWIRED",
)
require(
    "NativeMobileStartupGate(" in native
    and "FlutterNativeSecretStore()" in native
    and "NativeStartupDisposition.fullReauthentication" in native
    and "NativeStartupDisposition.locked" in native
    and "NativeLoginScreen(" not in native
    and "NativeHttpAuthPort(" not in native,
    "STARTUP_PROTECTED_FENCE",
)
require(
    "await journal.arm()" in first
    and "await journal.requiresReauthentication()" in first
    and "Recovery requires a separate MFA challenge" in recovery
    and "await journal.confirmFullReauthentication(" in recovery,
    "ISSUANCE_RECOVERY_CHECKPOINTS",
)
require(
    'https://dev.vencira.es/' in public_gate
    and "LaunchMode.externalApplication" in public_gate
    and "NativeLoginScreen(" not in public_gate,
    "BROWSER_FALLBACK_RETAINED",
)
require(
    "/api/v1/mobile/auth/password/" in auth
    and "/api/v1/mobile/auth/recover/mfa/" in auth
    and "/api/v1/mobile/token/revoke/" in auth
    and "followRedirects = false" in auth
    and "response.headers.containsKey('set-cookie')" in auth,
    "CLIENT_CONTRACT_DEFINITIONS",
)
print("D18_NATIVE_AUTH_OPERATIONAL_READINESS=BLOCKED", flush=True)
print("D18_NATIVE_ISSUER_DEPLOYED=NO", flush=True)
print("D18_STATIC_FENCE_GATE=PASS", flush=True)
print("MFA_RELEASE_AUTHORIZED=NO", flush=True)
print("NO_DEPLOY_NO_LIVE_MIGRATION=1", flush=True)
