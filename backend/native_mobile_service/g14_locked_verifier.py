"""G14-D test-only locked account verification boundary.

This component checks a password against the stored Django credential under
the account row lock. It deliberately refuses MFA-enabled identities, does
not return authentication assertions and never mints access/refresh tokens.
"""
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction

from reminders.models import UserMfaState
from reminders.native_mobile_identity_gate import (
    MobileIdentityDenied, mobile_credential_version, require_mobile_identity_gate,
)

from .session_store import _gate, _generation, MobileTokenDenied


class CandidateVerificationDenied(Exception):
    """Uniform result regardless of account presence or password correctness."""


def verify_candidate_password_only(*, username, password):
    """Verify only accounts with MFA disabled; no token issuance.

    A future issuer must recheck these conditions under its OWN lock. Returning
    account metadata is not authority for later issuance or MFA bypass.
    """
    try:
        _gate()
        if (type(username) is not str or not username or len(username) > 150
                or username != username.strip() or type(password) is not str
                or not password):
            raise CandidateVerificationDenied()
        with transaction.atomic():
            User = get_user_model()
            if User.USERNAME_FIELD != "username":
                raise CandidateVerificationDenied()
            user = User.objects.select_for_update().filter(
                username=username, is_active=True,
            ).first()
            if user is None or not user.check_password(password):
                raise CandidateVerificationDenied()
            if UserMfaState.objects.filter(user_id=user.pk, enabled=True).exists():
                raise CandidateVerificationDenied()
            require_mobile_identity_gate(
                user=user, verified_mfa=False, asserted_mfa_epoch=None,
                asserted_credential_version=mobile_credential_version(user),
            )
            # Retain only server-side metadata; never return a token or MFA proof.
            return user.pk, _generation(user.pk)
    except (MobileTokenDenied, MobileIdentityDenied) as exc:
        raise CandidateVerificationDenied() from exc
