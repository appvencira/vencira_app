"""D1.5h: pruebas de fail-closed y rotación de claves MFA."""
from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .mfa_key_config import load_mfa_keys
from .mfa_secrets import decrypt_totp_secret, encrypt_totp_secret


class MfaKeyConfigTests(SimpleTestCase):
    def test_absent_blank_bad_and_repeated_keys_fail_closed(self):
        valid = Fernet.generate_key().decode("ascii")
        for raw in ["", " ", "not-a-key", valid + ",", "," + valid,
                    valid + "," + valid, "á" * 44]:
            with self.subTest(raw_length=len(raw)):
                with self.assertRaises(ValueError):
                    load_mfa_keys(environ={"VENCIRA_MFA_FERNET_KEYS": raw})
        with self.assertRaises(ValueError):
            load_mfa_keys(environ={})

    def test_primary_encrypts_and_secondary_supports_rotation(self):
        old, new = (Fernet.generate_key().decode("ascii") for _ in range(2))
        old_ciphertext = encrypt_totp_secret("ABCDEFGHIJKLMNOP", user_id=42, keys=[old])
        loaded = load_mfa_keys(environ={"VENCIRA_MFA_FERNET_KEYS": new + "," + old})
        self.assertEqual(decrypt_totp_secret(old_ciphertext, user_id=42, keys=loaded),
                         "ABCDEFGHIJKLMNOP")
        new_ciphertext = encrypt_totp_secret("ABCDEFGHIJKLMNOP", user_id=42, keys=loaded)
        self.assertEqual(decrypt_totp_secret(new_ciphertext, user_id=42, keys=[new]),
                         "ABCDEFGHIJKLMNOP")
        with self.assertRaises(ValueError):
            decrypt_totp_secret(new_ciphertext, user_id=42, keys=[old])


    def test_restricted_file_and_conflicting_sources(self):
        import os
        import tempfile
        from pathlib import Path
        key = Fernet.generate_key().decode("ascii")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mfa-key"
            path.write_text(key + "\n", encoding="ascii")
            os.chmod(path, 0o600)
            self.assertEqual(load_mfa_keys(environ={
                "VENCIRA_MFA_FERNET_KEYS_FILE": str(path),
            }), [key])
            with self.assertRaises(ValueError):
                load_mfa_keys(environ={
                    "VENCIRA_MFA_FERNET_KEYS_FILE": str(path),
                    "VENCIRA_MFA_FERNET_KEYS": key,
                })
            os.chmod(path, 0o644)
            with self.assertRaises(ValueError):
                load_mfa_keys(environ={"VENCIRA_MFA_FERNET_KEYS_FILE": str(path)})
            os.chmod(path, 0o600)
            link = Path(directory) / "alias"
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                load_mfa_keys(environ={"VENCIRA_MFA_FERNET_KEYS_FILE": str(link)})
