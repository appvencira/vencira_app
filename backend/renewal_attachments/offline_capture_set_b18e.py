"""B18E: fail-closed synthetic DB/object/journal capture catalogue.

Pure validation; never freezes writers, opens files, or authorizes a release.
The inventories must be independently sampled during a real controlled cut.
"""
import hashlib
import hmac
import json
import re

class CaptureSetError(ValueError):
    pass

_HEX = re.compile(r"[0-9a-f]{64}\Z")
_ID = re.compile(r"[0-9a-f]{32}\Z")

def _sha(data):
    return hashlib.sha256(data).hexdigest()

def verify_capture_set(*, before, after, db_records, encrypted_objects,
                       journals, missing_writers=(), drained=False):
    """All values are synthetic in tests; read-only and strict by design."""
    try:
        if not isinstance(drained, bool) or not drained:
            raise ValueError("WRITERS_NOT_DRAINED")
        if type(missing_writers) not in (list, tuple) or missing_writers:
            raise ValueError("WRITER_COVERAGE_INCOMPLETE")
        if type(db_records) is not dict or not db_records or len(db_records) > 10000:
            raise ValueError("INVALID_DB_INVENTORY")
        if type(encrypted_objects) is not dict or type(journals) is not dict:
            raise ValueError("INVALID_OBJECT_INVENTORY")
        if set(db_records) != set(encrypted_objects) or set(db_records) != set(journals):
            raise ValueError("UNPAIRED_COMPONENTS")
        for key, record in db_records.items():
            if type(key) is not str or not _ID.fullmatch(key):
                raise ValueError("INVALID_OBJECT_ID")
            if type(record) is not dict or set(record) != {"cipher_sha256", "journal_sha256"}:
                raise ValueError("INVALID_DB_RECORD")
            obj, journal = encrypted_objects[key], journals[key]
            if (type(obj) is not bytes or not obj or type(journal) is not bytes
                    or not journal or len(obj) > 16*1024*1024 or len(journal) > 4096):
                raise ValueError("INVALID_COMPONENT_SIZE")
            for field in ("cipher_sha256", "journal_sha256"):
                if type(record[field]) is not str or not _HEX.fullmatch(record[field]):
                    raise ValueError("INVALID_DIGEST")
            if not hmac.compare_digest(_sha(obj), record["cipher_sha256"]):
                raise ValueError("CIPHER_MISMATCH")
            if not hmac.compare_digest(_sha(journal), record["journal_sha256"]):
                raise ValueError("JOURNAL_MISMATCH")
            event = json.loads(journal)
            if (type(event) is not dict or set(event) != {"version","storage_key","state"}
                    or type(event["version"]) is not int or event["version"] != 1
                    or event["storage_key"] != key or event["state"] != "pending"):
                raise ValueError("JOURNAL_INVALID")
        if type(before) is not dict or type(after) is not dict or before != after:
            raise ValueError("CAPTURE_EPOCH_CHANGED")
        if set(before) != {"epoch","snapshot","inventory_sha256"}:
            raise ValueError("INVALID_MARKER")
        if (type(before["epoch"]) is not int or before["epoch"] < 0
                or type(before["snapshot"]) is not str or not before["snapshot"]
                or len(before["snapshot"]) > 64
                or type(before["inventory_sha256"]) is not str
                or not _HEX.fullmatch(before["inventory_sha256"])):
            raise ValueError("INVALID_MARKER")
        raw = json.dumps(db_records, sort_keys=True, separators=(",",":")).encode()
        if not hmac.compare_digest(_sha(raw), before["inventory_sha256"]):
            raise ValueError("MARKER_INVENTORY_MISMATCH")
        return {"verified": True, "objects": len(db_records), "release_authorized": False}
    except (TypeError, ValueError, KeyError, AttributeError, UnicodeError, OverflowError) as exc:
        raise CaptureSetError("CAPTURE_SET_NOT_VERIFIED") from exc
