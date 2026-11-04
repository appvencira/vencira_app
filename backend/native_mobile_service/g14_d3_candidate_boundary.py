"""G14-D3 laboratory-only composition for non-MFA identities.

No HTTP route. External MFA-backed issuance remains prohibited.
The outer database transaction retains D1 account locks until audit commits.
"""
import uuid
from django.db import transaction
from .g14_admission import admit_candidate_password_attempt
from .g14_locked_verifier import verify_candidate_password_only
from .g5_audit import record_candidate_auth_event
from .session_store import issue_verified_candidate_session


def candidate_non_mfa_flow(*, username, password, request_meta, event_id):
    if type(event_id) is not uuid.UUID:
        raise ValueError("Invalid event identifier")
    allowed = admit_candidate_password_attempt(
        account_key=username, request_meta=request_meta, denial_event_id=event_id,
    )
    if not allowed:
        return None
    with transaction.atomic():
        identity, generation = verify_candidate_password_only(
            username=username, password=password,
        )
        pair = issue_verified_candidate_session(
            user_id=identity, verified_mfa=False, mfa_epoch=None,
            expected_generation=generation,
        )
        record_candidate_auth_event(
            event_id=event_id, event_type="auth_verified", actor=username,
        )
        return pair
