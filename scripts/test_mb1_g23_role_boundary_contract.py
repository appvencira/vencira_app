import unittest
from scripts.mb1_g23_role_boundary_contract import ALL, ROLES, BOUNDARY, evaluate

def blank():
    return {k:{"verified":False,"artifact":""} for k in ALL}

class BoundaryContractTests(unittest.TestCase):
    def test_default_denial(self):
        r=evaluate(blank())
        self.assertEqual(len(r["unresolved"]),len(ALL))
        self.assertFalse(r["operational_authorized"])
    def test_roles_alone_are_insufficient(self):
        e=blank()
        for k in ROLES:e[k]={"verified":True,"artifact":"clone-report"}
        self.assertEqual(set(evaluate(e)["unresolved"]),set(BOUNDARY))
    def test_boundary_alone_insufficient(self):
        e=blank()
        for k in BOUNDARY:e[k]={"verified":True,"artifact":"host-report"}
        self.assertEqual(set(evaluate(e)["unresolved"]),set(ROLES))
    def test_full_self_attestation_still_not_authorized(self):
        e={k:{"verified":True,"artifact":"claim"} for k in ALL}
        r=evaluate(e)
        self.assertFalse(r["unresolved"])
        self.assertFalse(r["operational_authorized"])
        self.assertTrue(r["independent_review_required"])
    def test_missing_rejected(self):
        e=blank();e.pop(ALL[0])
        with self.assertRaises(ValueError):evaluate(e)
    def test_unknown_rejected(self):
        e=blank();e["override"]={"verified":True,"artifact":"a"}
        with self.assertRaises(ValueError):evaluate(e)
    def test_truthy_string_rejected(self):
        e=blank();e[ALL[0]]={"verified":"true","artifact":"a"}
        with self.assertRaises(ValueError):evaluate(e)
    def test_empty_positive_rejected(self):
        e=blank();e[ALL[0]]={"verified":True,"artifact":" "}
        with self.assertRaises(ValueError):evaluate(e)
    def test_extra_fields_rejected(self):
        e=blank();e[ALL[0]]["override"]=True
        with self.assertRaises(ValueError):evaluate(e)
if __name__=="__main__":
    unittest.main()
