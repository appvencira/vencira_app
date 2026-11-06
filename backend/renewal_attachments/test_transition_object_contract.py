"""Regression for fail-closed object audit adjudication."""
import unittest
from renewal_attachments.transition_object_contract import object_audit_acceptable as accept

class ObjectAuditContractTests(unittest.TestCase):
    def base(self, **changes):
        d=dict(metadata_aligned=True,checked=2,expected=2,unreadable=0,
               digest_mismatches=0,size_mismatches=0)
        d.update(changes)
        return d

    def test_clean_two_objects(self): self.assertTrue(accept(**self.base()))
    def test_empty_aligned(self): self.assertTrue(accept(**self.base(checked=0,expected=0)))
    def test_unaligned(self): self.assertFalse(accept(**self.base(metadata_aligned=False)))
    def test_missing_object(self): self.assertFalse(accept(**self.base(checked=1)))
    def test_excess_object(self): self.assertFalse(accept(**self.base(checked=3)))
    def test_unreadable(self): self.assertFalse(accept(**self.base(unreadable=1)))
    def test_digest_mismatch(self): self.assertFalse(accept(**self.base(digest_mismatches=1)))
    def test_size_mismatch(self): self.assertFalse(accept(**self.base(size_mismatches=1)))
    def test_negative_count_fails(self):
        with self.assertRaisesRegex(ValueError,"INVALID_COUNTS"):
            accept(**self.base(expected=-1))
    def test_bool_count_fails(self):
        with self.assertRaisesRegex(ValueError,"INVALID_COUNTS"):
            accept(**self.base(checked=True))
    def test_non_boolean_alignment_fails(self):
        with self.assertRaisesRegex(ValueError,"INVALID_ALIGNMENT"):
            accept(**self.base(metadata_aligned="yes"))

if __name__=="__main__":
    unittest.main()
