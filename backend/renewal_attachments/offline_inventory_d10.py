"""D10: triple inventario de solo lectura, exclusivo para ensayos.

No concede acceso, no resuelve estados, no elimina archivos.
Requiere almacenes sin escrituras concurrentes para una instantánea estable.
"""
import os
import stat
import uuid

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError
from .models import RenewalAttachment


def _inventory(root, suffix):
    try:
        fd = os.open(
            root, os.O_RDONLY | os.O_DIRECTORY |
            getattr(os, "O_NOFOLLOW", 0)
        )
    except OSError as exc:
        raise PrivateStoreError("INVENTORY_ROOT_UNAVAILABLE") from exc

    try:
        info = os.fstat(fd)
        if not stat.S_ISDIR(info.st_mode) or info.st_mode & 0o077:
            raise PrivateStoreError("INVENTORY_ROOT_UNSAFE")

        found = set()
        for name in os.listdir(fd):
            expected_length = 32 + len(suffix)
            if (
                len(name) != expected_length
                or not name.endswith(suffix)
                or any(
                    ch not in "0123456789abcdef"
                    for ch in name[:32]
                )
            ):
                raise PrivateStoreError("INVENTORY_UNEXPECTED_OBJECT")

            item = os.stat(
                name, dir_fd=fd, follow_symlinks=False
            )
            if not stat.S_ISREG(item.st_mode) or item.st_mode & 0o077:
                raise PrivateStoreError("INVENTORY_OBJECT_UNSAFE")

            found.add(uuid.UUID(hex=name[:32]))
        return found
    except OSError as exc:
        raise PrivateStoreError("INVENTORY_READ_FAILED") from exc
    finally:
        os.close(fd)


def inspect_inventory_d10(*, journal, store):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("ISOLATED_REHEARSAL_ONLY")

    intents = _inventory(journal.root, ".json")
    objects = _inventory(store.root, "")

    # values_list evita extraer nombres de clientes o datos personales.
    metadata = set(
        RenewalAttachment.objects.values_list(
            "storage_key", flat=True
        )
    )

    report = {
        "intent_count": len(intents),
        "object_count": len(objects),
        "metadata_count": len(metadata),
        "objects_without_intent": len(objects - intents),
        "objects_without_metadata": len(objects - metadata),
        "intents_without_object": len(intents - objects),
        "metadata_without_intent": len(metadata - intents),
        "metadata_without_object": len(metadata - objects),
        "release_authorized": False,
    }
    report["requires_review"] = any(
        report[name] != 0 for name in (
            "objects_without_intent",
            "objects_without_metadata",
            "intents_without_object",
            "metadata_without_intent",
            "metadata_without_object",
        )
    )
    return report
