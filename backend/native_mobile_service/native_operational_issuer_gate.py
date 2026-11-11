"""D20 native issuer boundary: source-derived operational readiness, fail closed.

Do not confuse this policy with authentication. No credential can be minted,
no HTTP route is registered, and no request may provide its own evidence.
Successful policy checks are NEVER an issuance authorization.
"""
from dataclasses import dataclass

from django.conf import settings


@dataclass(frozen=True)
class NativeOperationalReadiness:
    environment: str
    service_installed: bool
    bearer_enabled: bool
    issuer_authorized: bool
    mobile_routes_authorized: bool
    production_key_custody_verified: bool
    mfa_trusted_issuer_verified: bool
    account_recovery_verified: bool
    abuse_and_audit_verified: bool
    mobile_device_https_verified: bool


_REQUIRED = (
    "issuer_authorized",
    "mobile_routes_authorized",
    "production_key_custody_verified",
    "mfa_trusted_issuer_verified",
    "account_recovery_verified",
    "abuse_and_audit_verified",
    "mobile_device_https_verified",
)


def operational_readiness_missing(context):
    """Missing *release* evidence, not an authentication or session proof."""
    if type(context) is not NativeOperationalReadiness:
        raise TypeError("Server-constructed native release readiness required")
    missing = []
    if context.environment != "production":
        missing.append("production_environment")
    if context.service_installed is not True:
        missing.append("operational_app_registration")
    if context.bearer_enabled is not True:
        missing.append("operational_bearer_policy")
    for name in _REQUIRED:
        if getattr(context, name) is not True:
            missing.append(name)
    return tuple(missing)


class NativeIssuerUnavailable(PermissionError):
    """Uniform blocked gate; no account, identity or secret detail."""


def assert_operational_issuer_unavailable():
    """Enforce the current hard release hold from server-owned settings.

    It intentionally NEVER returns successful authority or token material,
    even if tests override settings or submit all-true release evidence.
    Removal requires an independently reviewed operational issuer implementation
    and a specific, separately authorized release, not a flag flip.
    """
    if settings.VENCIRA_ENV != "production":
        raise NativeIssuerUnavailable("Native mobile issuer unavailable")
    if (
        not getattr(settings, "VENCIRA_NATIVE_SERVICE_CANDIDATE", False)
        or not getattr(settings, "VENCIRA_NATIVE_BEARER_ENABLED", False)
    ):
        raise NativeIssuerUnavailable("Native mobile issuer unavailable")
    raise NativeIssuerUnavailable("Native mobile issuer unavailable")
