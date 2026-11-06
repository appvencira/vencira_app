"""G14-B candidate-only security acceptance policy for a future trusted issuer.

This module never checks passwords, verifies TOTP, issues tokens or opens HTTP.
A caller cannot use this policy result as proof that any secret was checked.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class IssuanceSecurityEvidence:
    account_active: bool
    credential_version_current: bool
    generation_current: bool
    mfa_required: bool
    mfa_verified: bool
    mfa_epoch_current: bool
    recovery_quarantine_clear: bool
    abuse_budget_allowed: bool
    audit_ready: bool


def missing_issuance_requirements(evidence):
    """Return names of failed requirements, never an authorization credential."""
    if type(evidence) is not IssuanceSecurityEvidence:
        raise TypeError("G14 candidate evidence required")
    tests = (
        ("account", evidence.account_active),
        ("password_version", evidence.credential_version_current),
        ("generation", evidence.generation_current),
        ("recovery_quarantine", evidence.recovery_quarantine_clear),
        ("abuse_budget", evidence.abuse_budget_allowed),
        ("audit", evidence.audit_ready),
    )
    missing = [name for name, ok in tests if ok is not True]
    if evidence.mfa_required is not False and evidence.mfa_required is not True:
        missing.append("mfa_requirement_unknown")
    elif evidence.mfa_required:
        if evidence.mfa_verified is not True:
            missing.append("mfa_not_verified")
        if evidence.mfa_epoch_current is not True:
            missing.append("mfa_epoch")
    elif evidence.mfa_verified is not False:
        missing.append("unexpected_mfa_assertion")
    return tuple(missing)
