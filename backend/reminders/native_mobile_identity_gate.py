"""Security predicate for a FUTURE verified Android/iOS bearer identity.

This module DOES NOT parse, issue or accept bearer tokens, and is not wired
into DRF or any HTTP route. The actual token validator must be reviewed
separately and must call this check AFTER verifying signature, audience,
issuer, expiry, revocation and token provenance.

Django's existing MFA session middleware cannot protect an authenticated
DRF bearer principal: it runs before DRF attaches its request.user.
"""
from .models import MfaAdministrativeRecoveryCase, UserMfaState


class MobileIdentityDenied(Exception):
    """Fail-closed internal denial; never expose account state to clients."""


def require_mobile_identity_gate(
    *,
    user,
    verified_mfa,
    asserted_mfa_epoch,
):
    """Re-evaluate authoritative MFA and recovery state for EACH API request.

    verified_mfa and asserted_mfa_epoch must originate ONLY from a
    cryptographically verified, server-issued mobile identity token. Neither
    argument is an authentication proof on its own.

    Returns the active user only if the current MFA/recovery constraints are
    compatible with the verified assertion. Does not grant workspace access.
    """
    if (user is None or not getattr(user, "is_authenticated", False)
            or not getattr(user, "is_active", False)
            or not isinstance(getattr(user, "pk", None), int)
            or isinstance(user.pk, bool)):
        raise MobileIdentityDenied()

    if type(verified_mfa) is not bool:
        raise MobileIdentityDenied()

    if asserted_mfa_epoch is not None and (
        type(asserted_mfa_epoch) is not int
        or asserted_mfa_epoch < 0
        or asserted_mfa_epoch > 2147483647
    ):
        raise MobileIdentityDenied()

    try:
        state = UserMfaState.objects.filter(user_id=user.pk).first()
        cases = MfaAdministrativeRecoveryCase.objects.filter(subject_id=user.pk)
        pending = cases.filter(
            status=MfaAdministrativeRecoveryCase.Status.PENDING,
        ).exists()
        any_case = cases.exists()
    except Exception as exc:
        # Missing MFA tables, locked DB or failed credential-state lookup:
        # DENY instead of silently treating as MFA-disabled.
        raise MobileIdentityDenied() from exc

    if pending or (state is not None and not state.enabled and any_case):
        raise MobileIdentityDenied()

    if state is not None and state.enabled:
        if (not verified_mfa
                or asserted_mfa_epoch is None
                or asserted_mfa_epoch != state.session_epoch):
            raise MobileIdentityDenied()
    else:
        # A previously MFA-verified token MUST NOT survive disabling MFA,
        # even if the recovery case has since been closed.
        if verified_mfa or asserted_mfa_epoch is not None:
            raise MobileIdentityDenied()

    return user
