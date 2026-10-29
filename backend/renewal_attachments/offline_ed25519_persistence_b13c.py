"""B13C: recepción Ed25519 exclusiva de ensayos PG17.

No firma, no descifra y no concede acceso al documento.
La recepción HMAC histórica permanece independiente.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction

from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_write_barrier_b06b import advisory_barrier
from .offline_ed25519_b13b import verify_verdict


def persist_ed25519_evidence_offline(
    *,
    attachment_id,
    payload,
    signature,
    public_key,
    expected_fingerprint,
    now=None,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B13C_TEST_ONLY")

    if (
        type(expected_fingerprint) is not tuple
        or len(expected_fingerprint) != 6
    ):
        raise PermissionDenied("B13C_FINGERPRINT_REQUIRED")

    with advisory_barrier(capture=False):
        with transaction.atomic():
            attachment = (
                RenewalAttachment.objects
                .select_for_update()
                .get(pk=attachment_id)
            )

            fields = (
                "storage_key", "sha256", "byte_size",
                "state", "display_name", "content_type",
            )
            current = tuple(
                getattr(attachment, field) for field in fields
            )
            if current != expected_fingerprint:
                raise PermissionDenied("B13C_METADATA_CHANGED")

            if attachment.state != RenewalAttachment.State.QUARANTINED:
                raise PermissionDenied("B13C_NOT_QUARANTINED")

            if AttachmentScanEvidence.objects.filter(
                attachment=attachment
            ).exists():
                raise PermissionDenied("B13C_DUPLICATE")

            if not verify_verdict(
                payload=payload,
                signature=signature,
                public_key=public_key,
                attachment=attachment,
                now=now,
            ):
                raise PermissionDenied("B13C_SIGNATURE_INVALID")

            return AttachmentScanEvidence.objects.create(
                attachment=attachment,
                payload=payload,
                signature=signature,
            )
