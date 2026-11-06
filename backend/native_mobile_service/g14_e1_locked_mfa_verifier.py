"""G14-E1: server-side password + MFA verification in disposable tests.

This proof-of-verification NEVER returns an issuance grant, user id, factor
assertion or token. It is intentionally not a production authentication API.
"""
from django.contrib.auth import get_user_model
from django.db import transaction

from reminders.models import MfaAdministrativeRecoveryCase, UserMfaState
from reminders.mfa_store import consume_totp
from .session_store import _gate, MobileTokenDenied


class CandidateMfaDenied(Exception):
    """Uniform candidate denial; no account or factor details."""


def verify_candidate_password_and_totp(*, username, password, code, keys,
                                       timestamp=None):
    try:
        _gate()
        if (type(username) is not str or not username or len(username) > 150
                or username != username.strip()
                or type(password) is not str or not password
                or type(code) is not str or len(code) != 6
                or not code.isascii() or not code.isdecimal()
                or not isinstance(keys, list) or not keys):
            raise CandidateMfaDenied()
        with transaction.atomic():
            User = get_user_model()
            if User.USERNAME_FIELD != "username":
                raise CandidateMfaDenied()
            user = User.objects.select_for_update().filter(
                username=username, is_active=True,
            ).first()
            if user is None or not user.check_password(password):
                raise CandidateMfaDenied()
            # The user lock must remain held until the MFA state is consumed.
            state = UserMfaState.objects.select_for_update().filter(
                user_id=user.pk, enabled=True,
            ).first()
            if state is None or MfaAdministrativeRecoveryCase.objects.filter(
                subject_id=user.pk,
                status=MfaAdministrativeRecoveryCase.Status.PENDING,
            ).exists():
                raise CandidateMfaDenied()
            # Reuses the existing anti-replay writer under the same transaction.
            # A successful proof is deliberately not returned as a capability.
            if not consume_totp(user.pk, code, keys=keys, timestamp=timestamp):
                return False
            return True
    except (MobileTokenDenied, ValueError):
        # Invalid or unavailable MFA key material must not expose details.
        # Any MFA writer changes are rolled back by the atomic boundary.
        raise CandidateMfaDenied() from None
