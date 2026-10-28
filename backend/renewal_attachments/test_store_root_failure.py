import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from reminders.attachment_private_store import (
    PrivateQuarantineStore,
    PrivateStoreError,
)


class PrivateStoreRootFailureTests(SimpleTestCase):

    def test_missing_object_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "quarantine"
            root.mkdir(mode=0o700)
            store = PrivateQuarantineStore(root, Fernet.generate_key())

            # Objeto ausente con almacén disponible.
            store.discard_quarantine(uuid.uuid4())

    def test_missing_root_is_not_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "quarantine"
            root.mkdir(mode=0o700)
            store = PrivateQuarantineStore(root, Fernet.generate_key())

            root.rmdir()

            # Si desaparece el almacén, debe quedar pendiente.
            with self.assertRaises(PrivateStoreError):
                store.discard_quarantine(uuid.uuid4())
