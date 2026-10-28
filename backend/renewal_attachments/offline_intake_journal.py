"""D5A: registro duradero de intención, exclusivo para ensayos.

No es un endpoint, no almacena PII y no autoriza operaciones.
"""
import json
import os
import re
import stat
import uuid

from django.conf import settings
from django.core.exceptions import PermissionDenied

from reminders.attachment_private_store import PrivateStoreError


def _guard():
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED", False
        )
    ):
        raise PermissionDenied("Solo ensayos aislados")


class IntakeJournal:
    def __init__(self, root):
        self.root = root

    def _open_root(self):
        try:
            fd = os.open(
                self.root,
                os.O_RDONLY | os.O_DIRECTORY |
                getattr(os, "O_NOFOLLOW", 0),
            )
        except OSError as exc:
            raise PrivateStoreError("Registro no disponible") from exc

        mode = os.fstat(fd).st_mode
        if not stat.S_ISDIR(mode) or mode & 0o077:
            os.close(fd)
            raise PrivateStoreError("Registro con permisos inseguros")
        return fd

    def record_intent(self, key, sha256):
        _guard()

        if type(key) is not uuid.UUID:
            raise PrivateStoreError("Identificador inválido")
        if not isinstance(sha256, str) or not re.fullmatch(
            r"[0-9a-f]{64}", sha256
        ):
            raise PrivateStoreError("Huella inválida")

        payload = json.dumps({
            "version": 1,
            "storage_key": key.hex,
            "sha256": sha256,
            "state": "pending",
        }, sort_keys=True).encode()

        directory = self._open_root()
        name = key.hex + ".json"
        fd = None

        try:
            fd = os.open(
                name,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL |
                getattr(os, "O_NOFOLLOW", 0),
                0o600,
                dir_fd=directory,
            )
            with os.fdopen(fd, "wb") as stream:
                fd = None
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())

            os.fsync(directory)

        except OSError as exc:
            raise PrivateStoreError(
                "No se ha podido confirmar la intención"
            ) from exc
        finally:
            if fd is not None:
                os.close(fd)
            os.close(directory)

        return key

    def read_intent(self, key):
        _guard()
        if type(key) is not uuid.UUID:
            raise PrivateStoreError("Identificador inválido")

        directory = self._open_root()
        try:
            fd = os.open(
                key.hex + ".json",
                os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
                dir_fd=directory,
            )
            with os.fdopen(fd, "rb") as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                    raise PrivateStoreError("Registro inseguro")
                data = stream.read(1025)
            if len(data) > 1024:
                raise PrivateStoreError("Registro demasiado grande")
            result = json.loads(data)
            if (
                result.get("version") != 1
                or result.get("storage_key") != key.hex
                or result.get("state") != "pending"
                or not isinstance(result.get("sha256"), str)
                or not re.fullmatch(r"[0-9a-f]{64}", result["sha256"])
            ):
                raise PrivateStoreError("Registro inconsistente")
            return result
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            raise PrivateStoreError("Registro ilegible") from exc
        finally:
            os.close(directory)
