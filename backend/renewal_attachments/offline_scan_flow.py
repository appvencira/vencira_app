"""Test-only offline intake and quarantine scan orchestration.

Does not write scanner verdict to DB or make any document downloadable.
No HTTP endpoint calls this module.
"""
from dataclasses import dataclass
from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_scanner_worker import scan_and_attest_quarantine
from .offline_intake import stage_authorized_attachment


@dataclass(frozen=True)
class IntakeScanOutcome:
    attachment_id: object
    verdict: str
    attested: bool
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
    result = scan_and_attest_quarantine(
        store=store, attachment=item, socket_path=unix_socket,
        engine=engine, signing_key=signing_key, scanner=scanner)
    return IntakeScanOutcome(
        attachment_id=item.pk, verdict=result.verdict,
        attested=result.attestation is not None)
