"""B14B/C: contrato de escaneo y firma, solo ensayos.

No modifica estados, no escribe en BD y no libera archivos.
La separación operacional del firmante sigue pendiente.
"""
from dataclasses import dataclass
from django.conf import settings

from reminders.attachment_scan_pipeline import (
    scan_encrypted_quarantine,
)
from reminders.attachment_clamav_adapter import scan_with_clamd
from renewal_attachments.offline_keyed_v3_b13e import (
    issue_keyed_verdict,
)


@dataclass(frozen=True)
class SignedScanOutcome:
    verdict: str
    payload: dict | None = None
    signature: str | None = None
    release_allowed: bool = False


def scan_and_sign_v3(
    *,
    store,
    attachment,
    socket_path,
    private_key,
    key_id,
    engine,
    scanner=scan_with_clamd,
    now=None,
):
    blocked = SignedScanOutcome(verdict="blocked")

    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        return blocked

    fields = (
        "storage_key", "sha256", "byte_size",
        "state", "display_name", "content_type",
    )

    try:
        before = tuple(
            getattr(attachment, field) for field in fields
        )
        if before[3] != "quarantined":
            return blocked

        result = scan_encrypted_quarantine(
            store=store,
            attachment=attachment,
            socket_path=socket_path,
            scanner=scanner,
        )

        after = tuple(
            getattr(attachment, field) for field in fields
        )

        if (
            result.verdict != "clean"
            or result.release_allowed is not False
            or after != before
            or after[3] != "quarantined"
        ):
            return blocked

        payload, signature = issue_keyed_verdict(
            private_key=private_key,
            key_id=key_id,
            attachment=attachment,
            engine=engine,
            now=now,
        )

        if tuple(
            getattr(attachment, field) for field in fields
        ) != before:
            return blocked

        return SignedScanOutcome(
            verdict="attested",
            payload=payload,
            signature=signature,
        )

    except (
        AttributeError, TypeError, ValueError,
        OSError, RuntimeError, OverflowError,
    ):
        return blocked
