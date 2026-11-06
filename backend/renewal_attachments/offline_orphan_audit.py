"""Auditoría de cuarentena de solo lectura, limitada a tests."""
import os
import stat

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError
from .models import RenewalAttachment


def inspect_orphan_quarantine(*, store):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("Solo ensayos aislados")

    try:
        fd = os.open(
            store.root,
            os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0),
        )
    except OSError as exc:
        raise PrivateStoreError("Almacén no disponible") from exc

    try:
        info = os.fstat(fd)
        if not stat.S_ISDIR(info.st_mode) or info.st_mode & 0o077:
            raise PrivateStoreError("Permisos inseguros")

        observed = set()
        for name in os.listdir(fd):
            if (
                len(name) != 32
                or any(c not in "0123456789abcdef" for c in name)
            ):
                raise PrivateStoreError("Nombre de objeto inesperado")

            item = os.stat(name, dir_fd=fd, follow_symlinks=False)
            if not stat.S_ISREG(item.st_mode) or item.st_mode & 0o077:
                raise PrivateStoreError("Objeto inseguro")

            observed.add(name)

    except OSError as exc:
        raise PrivateStoreError("No se puede auditar el almacén") from exc
    finally:
        os.close(fd)

    registered = {
        key.hex
        for key in RenewalAttachment.objects.values_list(
            "storage_key", flat=True
        )
    }

    return {
        "stored_count": len(observed),
        "metadata_count": len(registered),
        "orphan_count": len(observed - registered),
        "missing_object_count": len(registered - observed),
        "consistent": observed == registered,
        "release_authorized": False,
    }
