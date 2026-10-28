"""D11 offline preflight: never authorizes download or changes stored data.

An authenticated synthetic scanner verdict is necessary but never sufficient.
Only test-mode rehearsal; no HTTP routes or customer data.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied

from .offline_recovery_d6 import classify_object
from .offline_scan_evidence_d11 import verify_scan_evidence_offline


def inspect_attachment_preflight_offline(*, attachment, journal, store,
                                         evidence, signature, secret):
    if settings.VENCIRA_ENV != "test" or not getattr(
        settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False
    ):
        raise PermissionDenied("ISOLATED_REHEARSAL_ONLY")

    report = {
        "object_verified": False,
        "scanner_evidence_verified": False,
        "metadata_consistent": False,
        "requires_review": True,
        "release_authorized": False,
        "download_allowed": False,
    }
    if attachment.pk is None or attachment.state != "quarantined":
        return report
    intent = journal.read_intent(attachment.storage_key)
    if intent["sha256"] != attachment.sha256:
        return report
    report["metadata_consistent"] = True
    if classify_object(
        journal=journal, store=store, key=attachment.storage_key
    ) != "verified":
        return report
    report["object_verified"] = True
    try:
        content = store.read_quarantine_for_scanner_only(attachment.storage_key)
        report["scanner_evidence_verified"] = verify_scan_evidence_offline(
            content=content, expected_digest=attachment.sha256,
            evidence=evidence, signature=signature, secret=secret
        )
    except (ValueError, OSError, PermissionDenied):
        return report

    # A clean signed verdict is NOT sufficient to open access.
    report["requires_review"] = True
    return report
