#!/usr/bin/env python3
"""D27–D28 release-boundary contract. Read-only, fail-closed.

This is an invariant audit, NOT an operational issuer implementation.
It must change through security review when operational routes are introduced.
"""
from __future__ import annotations

import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRODUCTION_URLS = "backend/config/urls.py"
PRODUCTION_SETTINGS = "backend/config/settings.py"
ANDROID_MAIN = "clients/flutter/lib/main.dart"
STARTUP = "clients/flutter/lib/ui/native_android_startup_boundary.dart"
ISSUER = "backend/native_mobile_service/native_operational_issuer_gate.py"

CANDIDATE_MODULES = (
    "candidate_challenge_store",
    "candidate_two_step_issuer",
    "candidate_recovery_issuer",
    "test_d22_http_views",
    "test_d22_urls",
    "test_i8k_recovery_urls",
)

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def audit_source(sources: dict[str, str]) -> tuple[str, ...]:
    """Pure and independently unit-testable boundary audit.

    No server flags or external claims can satisfy a missing implementation.
    """
    required = (PRODUCTION_URLS, PRODUCTION_SETTINGS, ANDROID_MAIN, STARTUP, ISSUER)
    if not all(path in sources and type(sources[path]) is str for path in required):
        return ("incomplete_source_inventory",)
    findings: list[str] = []
    for path in (PRODUCTION_URLS, PRODUCTION_SETTINGS, ISSUER):
        try:
            ast.parse(sources[path], filename=path)
        except SyntaxError:
            findings.append("invalid_python_source")
    urls = sources[PRODUCTION_URLS]
    settings = sources[PRODUCTION_SETTINGS]
    main = sources[ANDROID_MAIN]
    startup = sources[STARTUP]
    issuer = sources[ISSUER]
    if any(term in urls for term in ("native_mobile_service", "test_d22_urls",
                                      "test_i8k_recovery_urls")):
        findings.append("native_lab_or_unreviewed_operational_routes_present")
    if "VENCIRA_NATIVE_BEARER_ENABLED = False" not in settings:
        findings.append("native_bearer_release_fence_changed")
    if ('raise NativeIssuerUnavailable("Native mobile issuer unavailable")'
            not in issuer):
        findings.append("native_issuer_hard_deny_missing")
    if ("NativeAndroidStartupBoundary()" not in main
            or "NativeLoginScreen(" in main
            or "NativeFirstIssuanceEntry(" in main
            or "NativeHttpAuthPort(" in main):
        findings.append("android_operational_login_routed_without_review")
    if ("NativeMobileStartupGate(" not in startup
            or "NativeLoginScreen(" in startup
            or "NativeHttpAuthPort(" in startup):
        findings.append("startup_fence_changed")
    return tuple(findings)

def main() -> int:
    files = (PRODUCTION_URLS, PRODUCTION_SETTINGS, ANDROID_MAIN, STARTUP, ISSUER)
    try:
        findings = audit_source({name: read(name) for name in files})
    except (OSError, UnicodeError):
        findings = ("source_read_failure",)
    if findings:
        print("D27D28_OPERATIONAL_FENCE_INVARIANTS=FAIL")
        for finding in findings:
            print("D27D28_BLOCKER=" + finding)
        return 3
    print("D27D28_OPERATIONAL_FENCE_INVARIANTS=PASS")
    print("D27D28_CANDIDATE_BACKEND_REUSED_FOR_PRODUCTION=NO")
    print("D27D28_OPERATIONAL_ISSUER_IMPLEMENTED=NO")
    print("D27D28_ANDROID_NATIVE_LOGIN_CONNECTED=NO")
    print("D27D28_RELEASE_AUTHORIZED=NO")
    print("MFA_RELEASE_AUTHORIZED=NO")
    print("NO_DEPLOY_NO_LIVE_MIGRATION=1")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
