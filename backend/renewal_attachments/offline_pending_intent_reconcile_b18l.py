"""B18L: read-only reconciliation decision for pending synthetic journal intents.

Never deletes a journal or object, never promotes attachments, never
authorizes release. A pending intent is durable evidence, not disposable trash.
"""
from dataclasses import dataclass

@dataclass(frozen=True)
class PendingIntentDecision:
    classification: str
    requires_manual_review: bool = True
    release_authorized: bool = False
    delete_authorized: bool = False


def classify_pending_intent(*, journal_present, object_present,
                            metadata_present, object_digest_matches=None):
    values = (journal_present, object_present, metadata_present)
    if any(type(v) is not bool for v in values):
        raise ValueError("INVALID_RECONCILIATION_FLAGS")
    if object_digest_matches is not None and type(object_digest_matches) is not bool:
        raise ValueError("INVALID_DIGEST_FLAG")
    if not journal_present:
        return PendingIntentDecision("MISSING_JOURNAL_EVIDENCE")
    if object_present and object_digest_matches is not True:
        return PendingIntentDecision("OBJECT_DIGEST_UNVERIFIED")
    if metadata_present and not object_present:
        return PendingIntentDecision("METADATA_WITHOUT_OBJECT")
    if object_present and metadata_present:
        return PendingIntentDecision("PENDING_INTENT_WITH_COMPLETE_PAIR")
    if object_present:
        return PendingIntentDecision("ORPHAN_ENCRYPTED_OBJECT")
    return PendingIntentDecision("ORPHAN_PENDING_INTENT")
