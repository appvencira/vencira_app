"""D9: conciliación conservadora de diario, PG y cuarentena.

Solo ensayos. No modifica estados, archivos ni registros.
No autoriza publicación, descarga ni descarte.
"""
import os
import stat
import uuid

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError
from .models import RenewalAttachment
from .offline_recovery_d6 import classify_object


def inspect_reconciliation_d9(*, journal, store):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("Solo ensayos aislados")

    directory = journal._open_root()
    try:
        names = os.listdir(directory)
        keys = set()

        for name in names:
            if (
                len(name) != 37
                or not name.endswith(".json")
                or any(
                    c not in "0123456789abcdef"
                    for c in name[:32]
                )
            ):
                raise PrivateStoreError("Registro inesperado")

            info = os.stat(
                name, dir_fd=directory,
                follow_symlinks=False,
            )
            if (
                not stat.S_ISREG(info.st_mode)
                or info.st_mode & 0o077
            ):
                raise PrivateStoreError("Registro inseguro")

            keys.add(uuid.UUID(hex=name[:32]))
    except OSError as exc:
        raise PrivateStoreError(
            "No se puede inspeccionar el diario"
        ) from exc
    finally:
        os.close(directory)

    rows = {
        row.storage_key: row
        for row in RenewalAttachment.objects.all()
    }

    counts = {
        "consistent": 0,
        "metadata_missing": 0,
        "intent_missing": 0,
        "object_missing": 0,
        "mismatch": 0,
        "unavailable": 0,
        "release_authorized": False,
    }

    for key in keys:
        intent = journal.read_intent(key)
        record = rows.get(key)

        # Sin metadatos no existe propiedad verificable
        # de la renovación. Nunca se asigna automáticamente.
        if record is None:
            counts["metadata_missing"] += 1
            continue

        if (
            record.sha256 != intent["sha256"]
            or record.state != "quarantined"
        ):
            counts["mismatch"] += 1
            continue

        state = classify_object(
            journal=journal,
            store=store,
            key=key,
        )

        if state == "verified":
            counts["consistent"] += 1
        elif state == "missing":
            counts["object_missing"] += 1
        elif state == "unavailable":
            counts["unavailable"] += 1
        else:
            counts["mismatch"] += 1

    counts["intent_missing"] = len(
        set(rows) - keys
    )

    counts["requires_review"] = any(
        counts[name] > 0
        for name in (
            "metadata_missing",
            "intent_missing",
            "object_missing",
            "mismatch",
            "unavailable",
        )
    )

    # No devolver nombres, UUID, contenido ni huellas.
    return counts
