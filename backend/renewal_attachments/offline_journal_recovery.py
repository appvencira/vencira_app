"""D5C: diagnóstico de recuperación, solo ensayos y sin mutaciones."""
import hashlib
import os
import stat
import uuid

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError


def inspect_pending_intents(*, journal, store):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False
        )
    ):
        raise PermissionDenied("Solo ensayos aislados")

    directory = journal._open_root()
    try:
        names = os.listdir(directory)
        for name in names:
            if (
                len(name) != 37
                or not name.endswith(".json")
                or any(c not in "0123456789abcdef" for c in name[:32])
            ):
                raise PrivateStoreError("Registro inesperado")
            info = os.stat(
                name, dir_fd=directory, follow_symlinks=False
            )
            if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                raise PrivateStoreError("Registro inseguro")
    finally:
        os.close(directory)

    counts = {
        "pending_total": 0,
        "verified_object": 0,
        "missing_object": 0,
        "invalid_object": 0,
        "release_authorized": False,
    }

    for name in names:
        key = uuid.UUID(hex=name[:32])
        intent = journal.read_intent(key)
        counts["pending_total"] += 1

        try:
            content = store.read_quarantine_for_scanner_only(key)
        except PrivateStoreError:
            # No confundir archivo ausente, ilegible o volumen
            # inaccesible. Distinguirlos exige una fase posterior.
            counts["invalid_object"] += 1
            continue

        if hashlib.sha256(content).hexdigest() == intent["sha256"]:
            counts["verified_object"] += 1
        else:
            counts["invalid_object"] += 1

    return counts
