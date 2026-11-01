"""Unit contract tests for fail-closed G1-G3 gate."""
import unittest
from scripts.mb1_g123_evidence_gate import REQUIRED,adjudicate

def fixture():
    return {k: {"verified":False,"artifact":""} for k in REQUIRED}

class TestG123(unittest.TestCase):
    def test_all_missing_blocked(self):
        r=adjudicate(fixture())
        self.assertEqual(len(r["blocked"]),len(REQUIRED))
        self.assertFalse(r["operational_freeze_verified"])
        self.assertFalse(r["closure_ready"])
    def test_partial_does_not_authorize(self):
        e=fixture()
        e[REQUIRED[0]]={"verified":True,"artifact":"review-report-id"}
        r=adjudicate(e)
        self.assertEqual(len(r["blocked"]),len(REQUIRED)-1)
        self.assertFalse(r["operational_freeze_verified"])
    def test_self_asserted_full_still_not_freeze(self):
        e={k:{"verified":True,"artifact":"operator-evidence"} for k in REQUIRED}
        r=adjudicate(e)
        self.assertTrue(r["closure_ready"])
        self.assertFalse(r["operational_freeze_verified"])
    def test_missing_field_rejected(self):
        e=fixture();e.pop(REQUIRED[0])
        with self.assertRaises(ValueError): adjudicate(e)
    def test_unknown_field_rejected(self):
        e=fixture();e["override"]={"verified":True,"artifact":"x"}
        with self.assertRaises(ValueError): adjudicate(e)
    def test_truthy_string_rejected(self):
        e=fixture();e[REQUIRED[0]]={"verified":"true","artifact":"x"}
        with self.assertRaises(ValueError): adjudicate(e)
    def test_positive_without_artifact_rejected(self):
        e=fixture();e[REQUIRED[0]]={"verified":True,"artifact":" "}
        with self.assertRaises(ValueError): adjudicate(e)
    def test_extra_record_key_rejected(self):
        e=fixture();e[REQUIRED[0]]["bypass"]=True
        with self.assertRaises(ValueError): adjudicate(e)

if __name__=="__main__":unittest.main()
