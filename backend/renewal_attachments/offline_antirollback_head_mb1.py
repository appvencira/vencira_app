"""MB1 synthetic anti-rollback receipt and independently trusted head.

Test-only pure logic. A signed manifest alone does NOT prevent rollback.
The trusted head must be held on an independently protected external medium;
never infer it from the backup package being restored.
"""
import hashlib
import hmac
import json
import re

ID = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


class AntiRollbackError(ValueError):
    pass


def _canonical(item):
    return json.dumps(item, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def _key(key):
    if type(key) is not bytes or len(key) < 32:
        raise AntiRollbackError("INVALID_INDEPENDENT_KEY")


def _payload(value):
    if type(value) is not dict or set(value) != {
        "version", "sequence", "snapshot_id", "package_sha256", "previous_receipt_sha256"
    }:
        raise AntiRollbackError("INVALID_RECEIPT_FIELDS")
    if type(value["version"]) is not int or value["version"] != 1:
        raise AntiRollbackError("INVALID_VERSION")
    if type(value["sequence"]) is not int or not 1 <= value["sequence"] <= 2**63 - 1:
        raise AntiRollbackError("INVALID_SEQUENCE")
    if type(value["snapshot_id"]) is not str or not ID.fullmatch(value["snapshot_id"]):
        raise AntiRollbackError("INVALID_SNAPSHOT_ID")
    for field in ("package_sha256", "previous_receipt_sha256"):
        if type(value[field]) is not str or not HEX64.fullmatch(value[field]):
            raise AntiRollbackError("INVALID_SHA256")
    if value["sequence"] == 1 and value["previous_receipt_sha256"] != "0" * 64:
        raise AntiRollbackError("INVALID_GENESIS_LINK")
    if value["sequence"] > 1 and value["previous_receipt_sha256"] == "0" * 64:
        raise AntiRollbackError("MISSING_CHAIN_LINK")


def _no_duplicate_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise AntiRollbackError("DUPLICATE_JSON_FIELD")
        result[key] = value
    return result


def verify_receipt(receipt, authentication_key):
    _key(authentication_key)
    if type(receipt) is not bytes or not 1 <= len(receipt) <= 4096:
        raise AntiRollbackError("INVALID_RECEIPT_BYTES")
    try:
        record = json.loads(receipt, object_pairs_hook=_no_duplicate_pairs)
        if type(record) is not dict or set(record) != {"payload", "hmac_sha256"}:
            raise AntiRollbackError("INVALID_RECEIPT")
        payload = record["payload"]
        _payload(payload)
        tag = record["hmac_sha256"]
        if type(tag) is not str or not HEX64.fullmatch(tag):
            raise AntiRollbackError("INVALID_HMAC")
        if _canonical(record) != receipt:
            raise AntiRollbackError("NONCANONICAL_RECEIPT")
        expected = hmac.new(authentication_key, _canonical(payload), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(tag, expected):
            raise AntiRollbackError("UNAUTHENTICATED_RECEIPT")
        return payload
    except (ValueError, TypeError, UnicodeError, OverflowError) as exc:
        if isinstance(exc, AntiRollbackError):
            raise
        raise AntiRollbackError("INVALID_RECEIPT_ENCODING") from exc


def make_genesis(snapshot_id, package, authentication_key):
    return _issue(1, snapshot_id, package, "0" * 64, authentication_key)


def _issue(sequence, snapshot_id, package, previous_hash, authentication_key):
    _key(authentication_key)
    if type(package) is not bytes or not package:
        raise AntiRollbackError("INVALID_PACKAGE")
    payload = {
        "version": 1,
        "sequence": sequence,
        "snapshot_id": snapshot_id,
        "package_sha256": hashlib.sha256(package).hexdigest(),
        "previous_receipt_sha256": previous_hash,
    }
    _payload(payload)
    signature = hmac.new(authentication_key, _canonical(payload), hashlib.sha256).hexdigest()
    return _canonical({"payload": payload, "hmac_sha256": signature})


def issue_successor(trusted_head, snapshot_id, package, authentication_key):
    """Issue only the immediate next sequence from externally supplied head.

    Caller MUST advance protected external head after validating the backup
    and before treating the new package as the most recent recoverable one.
    """
    current = verify_receipt(trusted_head, authentication_key)
    if current["sequence"] == 2**63 - 1:
        raise AntiRollbackError("SEQUENCE_EXHAUSTED")
    return _issue(current["sequence"] + 1, snapshot_id, package,
                  hashlib.sha256(trusted_head).hexdigest(), authentication_key)


def verify_successor(trusted_head, candidate, authentication_key):
    current = verify_receipt(trusted_head, authentication_key)
    next_item = verify_receipt(candidate, authentication_key)
    if (next_item["sequence"] != current["sequence"] + 1 or
            next_item["previous_receipt_sha256"] !=
            hashlib.sha256(trusted_head).hexdigest()):
        raise AntiRollbackError("INVALID_CHAIN_CONTINUATION")
    return next_item


def verify_restore(trusted_external_head, candidate_receipt, package, authentication_key):
    """Authorize an offline *synthetic* restore only of externally trusted head.

    Both the receipt and the package can be perfectly valid yet stale.
    Fail closed unless the candidate equals the independently held head.
    """
    trusted = verify_receipt(trusted_external_head, authentication_key)
    candidate = verify_receipt(candidate_receipt, authentication_key)
    if type(package) is not bytes or not package:
        raise AntiRollbackError("INVALID_PACKAGE")
    if not hmac.compare_digest(trusted_external_head, candidate_receipt):
        raise AntiRollbackError("STALE_OR_UNTRUSTED_SNAPSHOT")
    if not hmac.compare_digest(
        candidate["package_sha256"], hashlib.sha256(package).hexdigest()
    ):
        raise AntiRollbackError("PACKAGE_DIGEST_MISMATCH")
    return {"verified": True, "sequence": trusted["sequence"],
            "snapshot_id": trusted["snapshot_id"], "release_authorized": False}
