"""B10D: unión experimental entre cuarentena y escáner.

Solo ensayos aislados. Nunca acepta identificadores de
almacenamiento aportados desde una petición HTTP.
No autoriza descargas, cambios de estado ni borrados.
"""
import hashlib
import hmac

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import (
    PrivateQuarantineStore,
    PrivateStoreError,
)
from .models import RenewalAttachment
from .offline_scan_pipeline_b10 import (
    scan_quarantine_offline,
    ScanPipelineRejected,
)
from .clamd_adapter import scan_with_clamd


def scan_stored_quarantine_offline(
    *,
    attachment_id,
    store,
    verification_key,
    socket_path,
    scanner=scan_with_clamd,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B10D_TEST_ONLY")

    if not isinstance(store, PrivateQuarantineStore):
        raise ScanPipelineRejected("INVALID_STORE")

    item = RenewalAttachment.objects.get(pk=attachment_id)

    if item.state != RenewalAttachment.State.QUARANTINED:
        raise ScanPipelineRejected("NOT_QUARANTINED")

    # El storage_key procede exclusivamente de la ficha
    # obtenida de la base de datos.
    try:
        content = store.read_quarantine_for_scanner_only(
            item.storage_key
        )
    except PrivateStoreError as exc:
        raise ScanPipelineRejected(
            "QUARANTINE_UNREADABLE"
        ) from exc

    if (
        type(content) is not bytes
        or len(content) != item.byte_size
        or not hmac.compare_digest(
            hashlib.sha256(content).hexdigest(),
            item.sha256,
        )
    ):
        raise ScanPipelineRejected(
            "QUARANTINE_INTEGRITY_FAILURE"
        )

    return scan_quarantine_offline(
        attachment_id=attachment_id,
        content=content,
        verification_key=verification_key,
        socket_path=socket_path,
        scanner=scanner,
    )
