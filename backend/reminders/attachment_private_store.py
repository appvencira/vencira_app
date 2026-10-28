"""Opt-in encrypted local quarantine primitive; no API or production wiring.

Caller must supply a dedicated attachment key (never an MFA key), a private
pre-existing root directory, and only synthetic or approved test content.
"""
import os
import stat
import uuid
from pathlib import Path

from cryptography.fernet import Fernet, InvalidToken


class PrivateStoreError(Exception):
    pass


class PrivateQuarantineStore:
    def __init__(self, root: Path, key: bytes):
        self.root = Path(root)
        if self.root.is_symlink() or not self.root.is_dir():
            raise PrivateStoreError("Almacén privado inexistente o inseguro")
        mode = self.root.stat().st_mode
        if not stat.S_ISDIR(mode) or mode & 0o077:
            raise PrivateStoreError("Permisos del almacén demasiado amplios")
        try:
            self.fernet = Fernet(key)
        except (TypeError, ValueError) as exc:
            raise PrivateStoreError("Clave de adjuntos inválida") from exc

    @staticmethod
    def _id(key: uuid.UUID) -> str:
        if type(key) is not uuid.UUID:
            raise PrivateStoreError("Identificador inválido")
        return key.hex

    def put_quarantine(self, key: uuid.UUID, payload: bytes) -> None:
        if not isinstance(payload, bytes) or not 0 < len(payload) <= 10 * 1024 * 1024:
            raise PrivateStoreError("Contenido inválido")
        name = self._id(key)
        token = self.fernet.encrypt(payload)
        fd = None
        directory_fd = None
        created = False
        try:
            # O_EXCL avoids overwriting; O_NOFOLLOW prohibits final symlink.
            directory_fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
            fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL |
                         getattr(os, "O_NOFOLLOW", 0), 0o600,
                         dir_fd=directory_fd)
            created = True
            with os.fdopen(fd, "wb") as file:
                fd = None
                file.write(token)
                file.flush()
                os.fsync(file.fileno())
        except (OSError, ValueError) as exc:
            if created and directory_fd is not None:
                try:
                    os.unlink(name, dir_fd=directory_fd)
                except OSError:
                    pass
            raise PrivateStoreError("No se pudo guardar en cuarentena") from exc
        finally:
            if fd is not None:
                os.close(fd)
            if directory_fd is not None:
                os.close(directory_fd)

    def read_quarantine_for_scanner_only(self, key: uuid.UUID) -> bytes:
        name = self._id(key)
        try:
            fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
            try:
                item = os.open(name, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0), dir_fd=fd)
                with os.fdopen(item, "rb") as file:
                    if not stat.S_ISREG(os.fstat(file.fileno()).st_mode):
                        raise PrivateStoreError("Objeto inválido")
                    token = file.read(16 * 1024 * 1024 + 1)
            finally:
                os.close(fd)
            if len(token) > 16 * 1024 * 1024:
                raise PrivateStoreError("Objeto demasiado grande")
            return self.fernet.decrypt(token)
        except (OSError, InvalidToken) as exc:
            raise PrivateStoreError("Objeto ilegible o inválido") from exc

    def discard_quarantine(self, key: uuid.UUID) -> None:
        """Remove a private staged object on failed metadata creation.

        Callers must check database ownership before use; not an HTTP delete.
        """
        name = self._id(key)
        try:
            # Abrir primero el almacén. Su ausencia NO equivale
            # a que el archivo individual haya sido descartado.
            try:
                fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY |
                             getattr(os, "O_NOFOLLOW", 0))
            except FileNotFoundError as exc:
                raise PrivateStoreError(
                    "Almacén privado no disponible") from exc
            try:
                try:
                    info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                except FileNotFoundError:
                    # Solo es idempotente la ausencia del objeto.
                    return
                if not stat.S_ISREG(info.st_mode):
                    raise PrivateStoreError("Objeto inseguro")
                os.unlink(name, dir_fd=fd)
                os.fsync(fd)
            finally:
                os.close(fd)
        except OSError as exc:
            raise PrivateStoreError("No se pudo descartar el objeto") from exc
