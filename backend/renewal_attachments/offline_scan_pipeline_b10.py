"""B10B/C: circuito de escaneo experimental.

No usar con archivos reales. El firmante NO está aislado;
el escáner y las claves son inyectados para pruebas.
No se habilitan estados CLEAN ni descargas.
"""
import hashlib
import hmac
import json
from datetime import datetime, timezone

from django.conf import settings
from django.core.exceptions import PermissionDenied

from .models import RenewalAttachment
from .clamd_adapter import (
    scan_with_clamd,
    MalwareDetected,
    MalwareScanUnavailable,
)
from .offline_scan_evidence import (
    persist_scan_evidence_offline,
)


class ScanPipelineRejected(Exception):
    pass


def scan_quarantine_offline(
    *, attachment_id, content, verification_key,
    socket_path, scanner=scan_with_clamd,
    now=None,
):
    """Escanea bytes sintéticos y registra evidencia limpia.

    La clave de firma se proporciona desde el ensayo.
    Nunca se genera ni persiste una clave real.
    """
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B10_TEST_ONLY")

    if (
        type(content) is not bytes
        or not 0 < len(content) <= 10 * 1024 * 1024
        or type(verification_key) is not bytes
        or len(verification_key) < 32
        or type(socket_path) is not str
        or not socket_path.startswith("/")
        or "\x00" in socket_path
        or not callable(scanner)
    ):
        raise ScanPipelineRejected("INVALID_SCAN_INPUT")

    item = RenewalAttachment.objects.get(pk=attachment_id)

    fields = (
        "storage_key", "sha256", "byte_size",
        "state", "display_name", "content_type",
    )
    fingerprint = tuple(getattr(item, f) for f in fields)

    if item.state != RenewalAttachment.State.QUARANTINED:
        raise ScanPipelineRejected("NOT_QUARANTINED")

    if (
        len(content) != item.byte_size
        or not hmac.compare_digest(
            hashlib.sha256(content).hexdigest(),
            item.sha256,
        )
    ):
        raise ScanPipelineRejected("CONTENT_MISMATCH")

    try:
        scanner(content, socket_path=socket_path)
    except (MalwareDetected, MalwareScanUnavailable):
        raise
    except Exception as exc:
        raise MalwareScanUnavailable(
            "SCANNER_UNEXPECTED_FAILURE"
        ) from exc

    instant = now or datetime.now(timezone.utc)
    if instant.tzinfo is None:
        raise ScanPipelineRejected("INVALID_TIME")

    payload = {
        "object_key": str(item.storage_key),
        "sha256": item.sha256,
        "verdict": "clean",
        "scanned_at": int(instant.timestamp()),
        "engine": "b10-test-adapter",
    }
    canonical = json.dumps(
        payload, sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
    ).encode("ascii")

    signature = hmac.new(
        verification_key, canonical,
        hashlib.sha256,
    ).hexdigest()

    evidence = persist_scan_evidence_offline(
        attachment_id=attachment_id,
        payload=payload,
        signature=signature,
        verification_key=verification_key,
        now=instant,
        expected_fingerprint=fingerprint,
    )
    return evidence
