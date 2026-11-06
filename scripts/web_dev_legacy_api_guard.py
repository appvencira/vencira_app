#!/usr/bin/env python3
"""Static fail-closed guard for the current DEV web-only cut.
Does not claim API functional compatibility or authorize deployment.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "clients/flutter/lib"


def main() -> int:
    detail = (LIB / "ui/renewal_detail_screen.dart").read_text()
    dashboard = (LIB / "ui/dashboard_screen.dart").read_text()
    dockerfile = (ROOT / "deploy/preview/Dockerfile.web").read_text()

    checks = {
        "attachments_disabled_by_default":
            bool(re.search(
                r"if\s*\(const bool\.fromEnvironment\(\s*"
                r"'VENCIRA_WEB_ATTACHMENTS_ENABLED',\s*defaultValue:\s*false"
                r"\s*\)\)\s*VenciraRenewalAttachmentsCard\(",
                detail)),
        "mfa_disabled_by_default":
            "if (const bool.fromEnvironment('VENCIRA_MFA_UI_ENABLED', defaultValue: false))"
            in dashboard,
        "build_not_enabling_incompatible_features":
            "VENCIRA_WEB_ATTACHMENTS_ENABLED" not in dockerfile
            and "VENCIRA_MFA_UI_ENABLED" not in dockerfile,
        "web_build_has_explicit_release":
            "flutter build web --release" in dockerfile,
    }

    # Every direct call to unavailable functions outside the adapter must be
    # understood. A new callsite changes this report and must be reviewed.
    allowed = {
        "fetchAttachmentManifest": {"ui/renewal_attachments_card.dart"},
        "fetchDeviceNoticePreview": set(),
        "startMfaSetup": {"ui/mfa_setup_screen.dart"},
        "confirmMfaSetup": {"ui/mfa_setup_screen.dart"},
        "acknowledgeMfaRecovery": {"ui/mfa_setup_screen.dart"},
    }
    for method, allowed_paths in allowed.items():
        callsites = []
        for source in LIB.rglob("*.dart"):
            rel = source.relative_to(LIB).as_posix()
            if rel.startswith("api/"):
                continue
            text = source.read_text()
            if re.search(r"\." + re.escape(method) + r"\s*\(", text):
                callsites.append(rel)
        unapproved = sorted(set(callsites) - allowed_paths)
        print(f"WEB_DEV_UNSUPPORTED_CALLSITE_{method}={';'.join(callsites) or 'NONE'}")
        checks[f"{method}_callsite_isolated"] = not unapproved

    for name, ok in checks.items():
        print(f"WEB_DEV_STATIC_{name}={'OK' if ok else 'FAIL'}")
    passed = all(checks.values())
    print(f"WEB_DEV_LEGACY_API_SOURCE_GATE={'PASS' if passed else 'FAIL'}")
    print("WEB_DEV_FUNCTIONAL_COMPATIBILITY=NOT_VERIFIED")
    print("WEB_DEV_DEPLOY_EXECUTED=NO")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
