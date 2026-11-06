"""Scanner-side only: perform a quarantine scan and sign its verified outcome.

Never call this from HTTP or a web process carrying the signing key.
No DB mutations and NO release of bytes regardless of verdict.
"""
from dataclasses import dataclass

from .attachment_scan_pipeline import scan_encrypted_quarantine
from .attachment_scan_attestation import issue_scan_attestation
from .attachment_scan_contract import verify_scan_verdict
from .attachment_clamav_adapter import scan_with_clamd


@dataclass(frozen=True)
class WorkerOutcome:
    verdict: str
    attestation: dict | None = None
    signature: str | None = None
    release_allowed: bool = False


def scan_and_attest_quarantine(*, store, attachment, socket_path, engine,
                               signing_key, scanner=scan_with_clamd, now=None):
    """Fail closed, signing only after scan of matching encrypted bytes."""
    # Pin metadata across the scan/sign boundary; never sign mutated objects.
    try:
        before = (attachment.storage_key, attachment.sha256,
                  attachment.byte_size, attachment.state,
                  attachment.display_name, attachment.content_type)
    except (AttributeError, TypeError):
        return WorkerOutcome(verdict="blocked")
    outcome = scan_encrypted_quarantine(
        store=store, attachment=attachment, socket_path=socket_path,
        scanner=scanner)
    if outcome.verdict != "clean":
        return WorkerOutcome(verdict="blocked")
    try:
        after = (attachment.storage_key, attachment.sha256,
                 attachment.byte_size, attachment.state,
                 attachment.display_name, attachment.content_type)
        if before != after or after[3] != "quarantined":
            return WorkerOutcome(verdict="blocked")
    except (AttributeError, TypeError):
        return WorkerOutcome(verdict="blocked")
    try:
        payload, signature = issue_scan_attestation(
            attachment=attachment, verdict="clean", engine=engine,
            signing_key=signing_key, now=now)
        if not verify_scan_verdict(
                payload=payload, signature=signature,
                verification_key=signing_key, attachment=attachment,
                now=now):
            return WorkerOutcome(verdict="blocked")
    except (TypeError, ValueError, AttributeError, OverflowError):
        return WorkerOutcome(verdict="blocked")
    return WorkerOutcome(verdict="attested", attestation=payload,
                         signature=signature)
