"""Security predicate for a FUTURE verified Android/iOS bearer identity.

This module DOES NOT parse, issue or accept bearer tokens, and is not wired
into DRF or any HTTP route. The actual token validator must be reviewed
separately and must call this check AFTER verifying signature, audience,
issuer, expiry, revocation and token provenance.

Django's existing MFA session middleware cannot protect an authenticated
DRF bearer principal: it runs before DRF attaches its request.user.
"""
from django.utils.crypto import constant_time_compare, salted_hmac

from .models import MfaAdministrativeRecoveryCase, UserMfaState


class MobileIdentityDenied(Exception):
    """Fail-closed internal denial; never expose account state to clients."""


def mobile_credential_version(user):
    """Domain-separated credential version, NOT the Django session hash.

    This version must be compared only after verifying a future token's
    signature. Never send get_session_auth_hash() to a mobile client.
    """
    return salted_hmac(
        'vencira.mobile.credential-version.v1',
        user.get_session_auth_hash(),
        algorithm='sha256',
    ).hexdigest()


def require_mobile_identity_gate(
    *,
    user,
    verified_mfa,
    asserted_mfa_epoch,
    asserted_credential_version,
):
    """Re-evaluate authoritative MFA and recovery state for EACH API request.

    Every asserted_* field must originate ONLY from a cryptographically
    verified, server-issued mobile identity token. Individual claims are not
    proof of authentication; in particular a client-supplied password hash
    must never be accepted by an HTTP endpoint.

    Returns the active user only if the current MFA/recovery constraints are
    compatible with the verified assertion. Does not grant workspace access.
    """
    if (user is None or not getattr(user, "is_authenticated", False)
            or not getattr(user, "is_active", False)
            or not isinstance(getattr(user, "pk", None), int)
            or isinstance(user.pk, bool)):
        raise MobileIdentityDenied()

    # Password rotation must invalidate old mobile identities. Use a
    # domain-separated version: never disclose Django's own session hash.
    try:
        if (not isinstance(asserted_credential_version, str)
                or len(asserted_credential_version) != 64
                or not constant_time_compare(
                    asserted_credential_version, mobile_credential_version(user)
                )):
            raise MobileIdentityDenied()
    except MobileIdentityDenied:
        raise
    except Exception as exc:
        raise MobileIdentityDenied() from exc

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

    # Historical recovery must not become an access bypass if the MFA state
    # row is absent or was disabled during recovery.
    if pending or (any_case and (state is None or not state.enabled)):
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
