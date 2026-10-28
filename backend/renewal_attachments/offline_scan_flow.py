"""Test-only offline intake and quarantine scan orchestration.

Does not write scanner verdict to DB or make any document downloadable.
No HTTP endpoint calls this module.
"""
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_scanner_worker import scan_and_attest_quarantine
from .offline_intake import stage_authorized_attachment
from .offline_scan_evidence import persist_scan_evidence_offline


@dataclass(frozen=True)
class IntakeScanOutcome:
    attachment_id: object
    verdict: str
    attested: bool
    evidence_recorded: bool = False
    release_allowed: bool = False


def intake_scan_offline(*, member, renewal_id, store, filename,
                        content_type, content, unix_socket,
                        engine, signing_key, scanner):
    """Stage first, scan immutable encrypted bytes, leave metadata quarantined.

    The supplied scanner is injectable for synthetic tests. Only a real,
    separately secured scanner process can serve as a release prerequisite.
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
            persist_scan_evidence_offline(
                attachment_id=item.pk, payload=result.attestation,
                signature=result.signature, verification_key=signing_key)
            recorded = True
    except Exception:
        verdict = "blocked"
        attested = False
        recorded = False
    return IntakeScanOutcome(
        attachment_id=item.pk, verdict=verdict, attested=attested,
        evidence_recorded=recorded)
