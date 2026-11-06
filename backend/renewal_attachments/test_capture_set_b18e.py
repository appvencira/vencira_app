import hashlib
import json
import unittest
from .offline_capture_set_b18e import verify_capture_set, CaptureSetError

class B18ECaptureSetTests(unittest.TestCase):
    def setUp(self):
        k = "a" * 32
        obj = b"encrypted-synthetic"
        journal = json.dumps({"version": 1, "storage_key": k, "state": "pending"}).encode()
        records = {k: {
            "cipher_sha256": hashlib.sha256(obj).hexdigest(),
            "journal_sha256": hashlib.sha256(journal).hexdigest(),
        }}
        mark = {
            "epoch": 1,
            "snapshot": "b18e-synthetic",
            "inventory_sha256": hashlib.sha256(json.dumps(
                records, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        }
        self.values = dict(before=mark, after=mark.copy(), db_records=records,
                           encrypted_objects={k: obj}, journals={k: journal},
                           missing_writers=(), drained=True)
        self.key = k

    def check_bad(self, **changes):
        with self.assertRaises(CaptureSetError):
            verify_capture_set(**{**self.values, **changes})

    def test_complete_synthetic_set(self):
        result = verify_capture_set(**self.values)
        self.assertTrue(result["verified"])
        self.assertEqual(result["objects"], 1)
        self.assertFalse(result["release_authorized"])

    def test_unfenced_writer(self):
        self.check_bad(missing_writers=("recovery_worker",))

    def test_writer_not_drained(self):
        self.check_bad(drained=False)

    def test_changed_epoch(self):
        self.check_bad(after={**self.values["after"], "epoch": 2})

    def test_changed_snapshot(self):
        self.check_bad(after={**self.values["after"], "snapshot": "later"})

    def test_missing_object(self):
        self.check_bad(encrypted_objects={})

    def test_missing_journal(self):
        self.check_bad(journals={})

    def test_cipher_tampering(self):
        self.check_bad(encrypted_objects={self.key: b"tampered"})

    def test_journal_tampering(self):
        self.check_bad(journals={self.key: b"tampered"})

    def test_unexpected_extra_object(self):
        self.check_bad(encrypted_objects={**self.values["encrypted_objects"], "b"*32:b"extra"})

    def test_untrusted_inventory_digest(self):
        self.check_bad(before={**self.values["before"], "inventory_sha256": "0"*64})

    def test_journal_identity_mismatch(self):
        forged = json.dumps({"version":1,"storage_key":"b"*32,"state":"pending"}).encode()
        records = {self.key: {**self.values["db_records"][self.key],
                              "journal_sha256":hashlib.sha256(forged).hexdigest()}}
        marker = {**self.values["before"],
                  "inventory_sha256":hashlib.sha256(json.dumps(
                     records,sort_keys=True,separators=(",",":")).encode()).hexdigest()}
        self.check_bad(db_records=records,before=marker,after=marker,
                       journals={self.key:forged})
