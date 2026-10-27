"""Synthetic test-only encrypted quarantine, never connects to live storage."""
import os
import tempfile
import uuid
from pathlib import Path

from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .attachment_private_store import PrivateQuarantineStore, PrivateStoreError


class PrivateQuarantineStoreTests(SimpleTestCase):
    def test_encrypted_storage_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "private"
            root.mkdir(mode=0o700)
            store = PrivateQuarantineStore(root, Fernet.generate_key())
            key = uuid.uuid4()
            content = b"synthetic PDF bytes for test"
            store.put_quarantine(key, content)
            raw = (root / key.hex).read_bytes()
            self.assertNotIn(content, raw)
            self.assertEqual((root / key.hex).stat().st_mode & 0o777, 0o600)
            self.assertEqual(store.read_quarantine_for_scanner_only(key), content)
            with self.assertRaises(PrivateStoreError):
                store.put_quarantine(key, content)
            self.assertEqual(store.read_quarantine_for_scanner_only(key), content)

    def test_reject_insecure_folder_and_invalid_key(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "private"
            root.mkdir(mode=0o700)
            os.chmod(root, 0o755)
            with self.assertRaises(PrivateStoreError):
                PrivateQuarantineStore(root, Fernet.generate_key())
            os.chmod(root, 0o700)
            with self.assertRaises(PrivateStoreError):
                PrivateQuarantineStore(root, b"invalid")

    def test_wrong_key_fails_without_disclosing_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "private"
            root.mkdir(mode=0o700)
            key = uuid.uuid4()
            PrivateQuarantineStore(root, Fernet.generate_key()).put_quarantine(key, b"demo")
            with self.assertRaises(PrivateStoreError):
                PrivateQuarantineStore(root, Fernet.generate_key()).read_quarantine_for_scanner_only(key)

    def test_reject_symlink_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "private"
            root.mkdir(mode=0o700)
            alias = Path(directory) / "alias"
            alias.symlink_to(root, target_is_directory=True)
            with self.assertRaises(PrivateStoreError):
                PrivateQuarantineStore(alias, Fernet.generate_key())
