"""D6A: clasificación fail-closed para ensayos aislados."""
import hashlib
import os
import stat

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError


def classify_object(*, journal, store, key):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False
        )
    ):
        raise PermissionDenied("Solo ensayos aislados")

    intent = journal.read_intent(key)

    # Abrir el volumen antes de comprobar el objeto.
    try:
        root_fd = os.open(
            store.root,
            os.O_RDONLY | os.O_DIRECTORY |
            getattr(os, "O_NOFOLLOW", 0),
        )
    except OSError:
        return "unavailable"

    try:
        info = os.fstat(root_fd)
        if not stat.S_ISDIR(info.st_mode) or info.st_mode & 0o077:
            return "unavailable"

        try:
            object_info = os.stat(
                key.hex,
                dir_fd=root_fd,
                follow_symlinks=False,
            )
        except FileNotFoundError:
            return "missing"
        except OSError:
            return "unavailable"

        if (
            not stat.S_ISREG(object_info.st_mode)
            or object_info.st_mode & 0o077
        ):
            return "invalid"

        try:
            content = store.read_quarantine_for_scanner_only(key)
        except PrivateStoreError:
            return "invalid"

        if hashlib.sha256(content).hexdigest() != intent["sha256"]:
            return "invalid"

        return "verified"
    finally:
        os.close(root_fd)
