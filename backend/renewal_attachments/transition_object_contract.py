"""Pure read-only adjudication of object verification results.

Never converts matching metadata into release permission.
"""
def object_audit_acceptable(*, metadata_aligned, checked, expected,
                            unreadable, digest_mismatches, size_mismatches):
    values=(checked,expected,unreadable,digest_mismatches,size_mismatches)
    if any(type(v) is not int or v < 0 for v in values):
        raise ValueError("OBJECT_AUDIT_INVALID_COUNTS")
    if type(metadata_aligned) is not bool:
        raise ValueError("OBJECT_AUDIT_INVALID_ALIGNMENT")
    return (metadata_aligned and checked == expected
            and unreadable == 0 and digest_mismatches == 0
            and size_mismatches == 0)
