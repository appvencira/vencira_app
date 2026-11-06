"""B17: receptor transaccional de ensayo. Sin endpoints públicos."""
import hashlib
import hmac
import json
import re
from datetime import datetime, timezone

from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection, transaction

from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_keyed_v3_b13e import verify_keyed_verdict
from .offline_write_barrier_b06b import advisory_barrier

DOMAIN = b"VENCIRA-EVIDENCE-TRANSPORT-V1\x00"
FIELDS = (
    "storage_key", "sha256", "byte_size",
    "state", "display_name", "content_type",
)


def canonical(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")


def receive_envelope_offline(
    *,
    envelope,
    transport_key,
    registry,
    attachment_id,
    expected_fingerprint,
    now,
    fail_after_evidence=False,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
    ):
        raise PermissionDenied("B17_TEST_ONLY")

    if (
        type(envelope) is not dict
        or set(envelope) != {"body", "mac"}
        or type(transport_key) is not bytes
        or len(transport_key) != 32
        or type(expected_fingerprint) is not tuple
        or len(expected_fingerprint) != 6
        or type(now) is not datetime
        or now.tzinfo is None
        or now.utcoffset() is None
    ):
        raise PermissionDenied("B17_INVALID_INPUT")

    body = envelope["body"]
    mac = envelope["mac"]

    if type(body) is not dict or set(body) != {
        "version", "timestamp", "nonce",
        "evidence", "signature",
    }:
        raise PermissionDenied("B17_INVALID_ENVELOPE")

    nonce = body["nonce"]

    if (
        type(body["version"]) is not int
        or body["version"] != 1
        or type(body["timestamp"]) is not int
        or not 0 <= int(now.timestamp()) - body["timestamp"] <= 120
        or type(nonce) is not str
        or not re.fullmatch(r"[0-9a-f]{32}", nonce)
        or type(mac) is not str
        or not re.fullmatch(r"[0-9a-f]{64}", mac)
    ):
        raise PermissionDenied("B17_INVALID_TRANSPORT")

    try:
        expected = hmac.new(
            transport_key,
            DOMAIN + canonical(body),
            hashlib.sha256,
        ).hexdigest()
    except (TypeError, ValueError, UnicodeError, OverflowError):
        raise PermissionDenied("B17_INVALID_PAYLOAD") from None

    if not hmac.compare_digest(mac, expected):
        raise PermissionDenied("B17_INVALID_MAC")

    # La barrera debe adquirirse antes de abrir la transacción.
    with advisory_barrier(capture=False):
        with transaction.atomic():
            with connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO b17_replay (nonce) VALUES (%s)",
                    [nonce],
                )

            attachment = (
                RenewalAttachment.objects
                .select_for_update()
                .get(pk=attachment_id)
            )

            current = tuple(
                getattr(attachment, field)
                for field in FIELDS
            )
            if current != expected_fingerprint:
                raise PermissionDenied("B17_METADATA_CHANGED")

            if AttachmentScanEvidence.objects.filter(
                attachment=attachment
            ).exists():
                raise PermissionDenied("B17_DUPLICATE_EVIDENCE")

            if not verify_keyed_verdict(
                payload=body["evidence"],
                signature=body["signature"],
                registry=registry,
                attachment=attachment,
                now=now,
            ):
                raise PermissionDenied("B17_UNTRUSTED_EVIDENCE")

            saved = AttachmentScanEvidence.objects.create(
                attachment=attachment,
                payload=body["evidence"],
                signature=body["signature"],
            )

            if fail_after_evidence:
                raise RuntimeError("B17_SIMULATED_ROLLBACK")

            return saved
