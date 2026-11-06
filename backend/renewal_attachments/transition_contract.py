"""Pure fail-closed contract for historical/independent attachment inventories.

No database or object access; never authorizes migration or release.
"""
from collections import Counter

FIELDS = (
    "id", "renewal_id", "uploaded_by_id", "display_name",
    "content_type", "byte_size", "sha256", "storage_key", "state", "created_at",
)


def compare_inventories(legacy, independent):
    """Return non-sensitive counts, raising on malformed/ambiguous inventories."""
    old, new = list(legacy), list(independent)
    for rows in (old, new):
        for row in rows:
            if not isinstance(row, dict) or set(row) != set(FIELDS):
                raise ValueError("ATTACHMENT_INVENTORY_SHAPE")
            if row["id"] is None or row["storage_key"] is None:
                raise ValueError("ATTACHMENT_INVENTORY_NULL_ID_OR_KEY")
        if len({r["id"] for r in rows}) != len(rows):
            raise ValueError("ATTACHMENT_DUPLICATE_IDS")
        key_counts = Counter(r["storage_key"] for r in rows)
        if any(n > 1 for n in key_counts.values()):
            raise ValueError("ATTACHMENT_DUPLICATE_STORAGE_KEYS")
    old_by_id = {r["id"]: r for r in old}
    new_by_id = {r["id"]: r for r in new}
    old_keys = {r["storage_key"]: r["id"] for r in old}
    new_keys = {r["storage_key"]: r["id"] for r in new}
    shared = old_by_id.keys() & new_by_id.keys()
    return {
        "legacy_count": len(old),
        "independent_count": len(new),
        "missing_in_independent": len(old_by_id.keys() - new_by_id.keys()),
        "missing_in_legacy": len(new_by_id.keys() - old_by_id.keys()),
        "conflicting_records": sum(old_by_id[k] != new_by_id[k] for k in shared),
        "reused_storage_keys": sum(
            old_keys[k] != new_keys[k] for k in old_keys.keys() & new_keys.keys()
        ),
    }
