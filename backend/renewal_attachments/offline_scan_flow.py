"""Test-only offline intake and quarantine scan orchestration.

Does not write scanner verdict to DB or make any document downloadable.
No HTTP endpoint calls this module.
"""
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_scanner_worker import scan_and_attest_quarantine
from reminders.attachment_clamav_adapter import scan_with_clamd
from .offline_intake import stage_authorized_attachment
from .offline_scan_evidence import persist_scan_evidence_offline
from .models import RenewalAttachment


@dataclass(frozen=True)
class IntakeScanOutcome:
    attachment_id: object
    verdict: str
    attested: bool
    evidence_recorded: bool = False
    release_allowed: bool = False


def intake_scan_offline(*, member, renewal_id, store, filename,
                        content_type, content, unix_socket,
                        engine, signing_key, scanner=scan_with_clamd):
    """Stage first, scan immutable encrypted bytes, leave metadata quarantined.

    Production-like rehearsal defaults to the real Unix-socket ClamAV adapter.
    A supplied fake scanner is only valid for isolated synthetic unit tests.
    Neither result gives permission to release file bytes.
    """
    if (settings.VENCIRA_ENV != "test" or
            not getattr(settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False)):
        raise PermissionDenied("Offline scan rehearsal only")
    item = stage_authorized_attachment(
        member=member, renewal_id=renewal_id, store=store, filename=filename,
        content_type=content_type, content=content)
    # The staged object remains quarantined on ANY scanner failure.
    # Exceptions must not accidentally propagate as a successful intake.
    try:
        result = scan_and_attest_quarantine(
            store=store, attachment=item, socket_path=unix_socket,
            engine=engine, signing_key=signing_key, scanner=scanner)
        verdict = result.verdict if result.verdict == "attested" else "blocked"
        attested = (verdict == "attested" and
                    result.attestation is not None and
                    result.signature is not None)
        recorded = False
        if attested:
            current = RenewalAttachment.objects.get(pk=item.pk)
            fingerprint = ("storage_key", "sha256", "byte_size", "state",
                           "display_name", "content_type")
            if any(getattr(current, field) != getattr(item, field)
                   for field in fingerprint):
                raise PermissionDenied("Attachment metadata changed during scan")
            persist_scan_evidence_offline(
                attachment_id=item.pk, payload=result.attestation,
                signature=result.signature, verification_key=signing_key,
                expected_fingerprint=tuple(getattr(item, field) for field in fingerprint))
            recorded = True
    except Exception:
        verdict = "blocked"
        attested = False
        recorded = False
    return IntakeScanOutcome(
        attachment_id=item.pk, verdict=verdict, attested=attested,
        evidence_recorded=recorded)
