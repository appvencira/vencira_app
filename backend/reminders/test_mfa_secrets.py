"""D1.5b: cifrado, rotación y códigos de recuperación sin modelos ni sesiones."""
from cryptography.fernet import Fernet
from django.test import SimpleTestCase

from .mfa_secrets import (
    decrypt_totp_secret, encrypt_totp_secret, generate_recovery_codes,
    hash_recovery_code, rotate_totp_secret, verify_recovery_code,
)
from .mfa_totp import generate_secret


class MfaSecretPrimitivesTests(SimpleTestCase):
    def test_ciphertext_does_not_expose_secret_and_is_bound_to_user(self):
        key = Fernet.generate_key().decode("ascii")
        secret = generate_secret()
        token = encrypt_totp_secret(secret, user_id=19, keys=[key])
        self.assertNotIn(secret, token)
        self.assertNotEqual(token, encrypt_totp_secret(secret, user_id=19, keys=[key]))
        self.assertEqual(decrypt_totp_secret(token, user_id=19, keys=[key]), secret)
        with self.assertRaises(ValueError):
            decrypt_totp_secret(token, user_id=20, keys=[key])
        with self.assertRaises(ValueError):
            decrypt_totp_secret(token[:-5] + "abcde", user_id=19, keys=[key])
        with self.assertRaises(ValueError):
            decrypt_totp_secret(token, user_id=19,
                                keys=[Fernet.generate_key().decode("ascii")])

    def test_rotation_reencrypts_and_old_key_can_be_removed(self):
        old, new = (Fernet.generate_key().decode("ascii") for _ in range(2))
        secret = generate_secret()
        encrypted = encrypt_totp_secret(secret, user_id=7, keys=[old])
        self.assertEqual(decrypt_totp_secret(encrypted, user_id=7, keys=[new, old]), secret)
        rotated = rotate_totp_secret(encrypted, user_id=7,
                                     old_keys=[new, old], new_keys=[new])
        self.assertEqual(decrypt_totp_secret(rotated, user_id=7, keys=[new]), secret)
        with self.assertRaises(ValueError):
            decrypt_totp_secret(rotated, user_id=7, keys=[old])

    def test_recovery_codes_are_unique_hashed_and_verifiable(self):
        codes = generate_recovery_codes()
        self.assertEqual(len(codes), 10)
        self.assertEqual(len(set(codes)), 10)
        for code in codes:
            encoded = hash_recovery_code(code)
            self.assertNotIn(code, encoded)
            self.assertTrue(verify_recovery_code(code, encoded))
            self.assertFalse(verify_recovery_code("A" * 32, encoded))
        with self.assertRaises(ValueError):
            hash_recovery_code("short")

    def test_missing_keys_and_invalid_data_fail_closed(self):
        with self.assertRaises(ValueError):
            encrypt_totp_secret(generate_secret(), user_id=1, keys=[])
        with self.assertRaises(ValueError):
            encrypt_totp_secret(generate_secret(), user_id=0,
                                keys=[Fernet.generate_key().decode("ascii")])
