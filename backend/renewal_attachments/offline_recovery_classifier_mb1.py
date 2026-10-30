"""MB1: conservative read-only classification of a three-way recovery inventory.

No deletion or repair capability. Input sets must come from a quiescent,
independently verified inventory; this function cannot establish a freeze.
"""
from collections.abc import Set
from uuid import UUID


class ReconciliationBlocked(RuntimeError):
    pass


def classify_recovery_inventory(*, intents, objects, metadata):
    for value in (intents, objects, metadata):
        if not isinstance(value, (set, frozenset)):
            raise ReconciliationBlocked("INVALID_INVENTORY")
        if len(value) > 100000 or any(type(key) is not UUID for key in value):
            raise ReconciliationBlocked("INVALID_INVENTORY")
    all_keys = intents | objects | metadata
    counts = {
        "complete": 0,
        "intent_without_object": 0,
        "object_without_metadata": 0,
        "object_without_intent": 0,
        "metadata_without_object": 0,
        "metadata_without_intent": 0,
        "intent_only": 0,
        "object_only": 0,
        "metadata_only": 0,
        "intent_and_object_without_metadata": 0,
        "object_and_metadata_without_intent": 0,
        "intent_and_metadata_without_object": 0,
    }
    for key in all_keys:
        i, o, m = key in intents, key in objects, key in metadata
        if i and o and m:
            counts["complete"] += 1
        elif i and not o and not m:
            counts["intent_only"] += 1
        elif o and not i and not m:
            counts["object_only"] += 1
        elif m and not i and not o:
            counts["metadata_only"] += 1
        elif i and o and not m:
            counts["intent_and_object_without_metadata"] += 1
        elif o and m and not i:
            counts["object_and_metadata_without_intent"] += 1
        elif i and m and not o:
            counts["intent_and_metadata_without_object"] += 1
        else:
            raise ReconciliationBlocked("UNKNOWN_INVENTORY_STATE")
        counts["intent_without_object"] += int(i and not o)
        counts["object_without_metadata"] += int(o and not m)
        counts["object_without_intent"] += int(o and not i)
        counts["metadata_without_object"] += int(m and not o)
        counts["metadata_without_intent"] += int(m and not i)
    # Even three existing components may have incompatible content or hashes.
    return {
        **counts,
        "total_keys": len(all_keys),
        "requires_review": len(all_keys) != counts["complete"],
        "content_verified": False,
        "consistent_snapshot_verified": False,
        "deletion_authorized": False,
        "repair_authorized": False,
        "release_authorized": False,
    }
