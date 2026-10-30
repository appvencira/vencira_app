"""Disposable MB1 E2E authenticated capture; synthetic-only, no operational release.

Fernet encrypts PostgreSQL dump + physical synthetic object/journal.
HMAC-SHA256 authenticates the manifest and ties all three to one snapshot.
The keys here are deliberately local to the disposable drill: NOT external custody.
"""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import sys

from cryptography.fernet import Fernet, InvalidToken

MAX_DB = 64 * 1024 * 1024
MAX_FILE = 16 * 1024 * 1024
SNAPSHOT = "mb1-dual-pg17-synthetic-v1"
ITEM = "a" * 32


def read(path, limit):
    p = Path(path)
    if p.is_symlink() or not p.is_file() or not 0 < p.stat().st_size <= limit:
        raise RuntimeError("INVALID_CAPTURE_FILE")
    return p.read_bytes()


def private_write(path, data):
    with open(path, "xb") as out:
        os.fchmod(out.fileno(), 0o600)
        out.write(data)
        out.flush()
        os.fsync(out.fileno())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":")).encode()


def guard(root):
    if os.environ.get("VENCIRA_ENV") != "test" or os.environ.get("MB1_DISPOSABLE_ONLY") != "1":
        raise RuntimeError("TEST_ONLY")
    root = Path(root)
    if root.is_symlink() or not root.is_dir() or root.stat().st_mode & 0o077:
        raise RuntimeError("UNSAFE_DIRECTORY")
    return root


def pack(root):
    dump = read(root / "source.dump", MAX_DB)
    obj = read(root / "objects" / ITEM, MAX_FILE)
    journal = read(root / "journal" / (ITEM + ".json"), MAX_FILE)
    key = Fernet.generate_key()
    auth = os.urandom(32)
    envelope = Fernet(key).encrypt(canonical({
        "snapshot": SNAPSHOT,
        "database": base64.b64encode(dump).decode(),
        "object": base64.b64encode(obj).decode(),
        "journal": base64.b64encode(journal).decode(),
    }))
    manifest = {
        "snapshot": SNAPSHOT, "database_sha256": digest(dump),
        "object_sha256": digest(obj), "journal_sha256": digest(journal),
        "envelope_sha256": digest(envelope),
        "item": ITEM, "key_id": "mb1-local-synthetic-only",
    }
    manifest_bytes = canonical(manifest)
    tag = hmac.new(auth, manifest_bytes, hashlib.sha256).hexdigest().encode()
    private_write(root / "capture.enc", envelope)
    private_write(root / "manifest.json", manifest_bytes)
    private_write(root / "manifest.mac", tag)
    keys = root / "keys"
    keys.mkdir(mode=0o700)
    private_write(keys / "encryption.key", key)
    private_write(keys / "authentication.key", auth)
    print("MB1_E2E_AUTHENTICATED_ENCRYPTED_SET=CREATED")


def verified(root, *, wrong_key=False, corrupt=False):
    manifest_bytes = read(root / "manifest.json", 8192)
    tag = read(root / "manifest.mac", 128)
    auth = read(root / "keys" / "authentication.key", 128)
    if wrong_key:
        auth = os.urandom(32)
    if not hmac.compare_digest(hmac.new(auth, manifest_bytes, hashlib.sha256).hexdigest().encode(), tag):
        raise RuntimeError("MANIFEST_AUTH_FAILED")
    manifest = json.loads(manifest_bytes)
    if manifest.get("snapshot") != SNAPSHOT or manifest.get("item") != ITEM:
        raise RuntimeError("SNAPSHOT_MISMATCH")
    envelope = read(root / "capture.enc", MAX_DB * 3)
    if corrupt:
        envelope = envelope[:-1] + bytes([envelope[-1] ^ 1])
    if digest(envelope) != manifest["envelope_sha256"]:
        raise RuntimeError("ENVELOPE_DIGEST_MISMATCH")
    try:
        payload = json.loads(Fernet(read(root / "keys" / "encryption.key", 128)).decrypt(envelope))
    except (InvalidToken, ValueError) as exc:
        raise RuntimeError("DECRYPT_FAILED") from exc
    if payload["snapshot"] != SNAPSHOT:
        raise RuntimeError("PAYLOAD_SNAPSHOT_MISMATCH")
    db = base64.b64decode(payload["database"], validate=True)
    obj = base64.b64decode(payload["object"], validate=True)
    journal = base64.b64decode(payload["journal"], validate=True)
    if any(digest(data) != manifest[field] for data, field in (
        (db, "database_sha256"), (obj, "object_sha256"), (journal, "journal_sha256")
    )):
        raise RuntimeError("CAPTURE_COMPONENT_MISMATCH")
    if obj != read(root / "objects" / ITEM, MAX_FILE) or journal != read(root / "journal" / (ITEM + ".json"), MAX_FILE):
        raise RuntimeError("OBJECT_OR_JOURNAL_DIFFER")
    return db


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in {"pack", "stream", "negative"}:
        raise SystemExit("USAGE")
    root = guard(sys.argv[2])
    action = sys.argv[1]
    if action == "pack":
        pack(root)
    elif action == "stream":
        sys.stdout.buffer.write(verified(root))
        sys.stdout.buffer.flush()
    else:
        for case in ({"wrong_key": True}, {"corrupt": True}):
            try:
                verified(root, **case)
            except RuntimeError:
                continue
            raise RuntimeError("NEGATIVE_ACCEPTED")
        print("MB1_E2E_WRONG_KEY_AND_TAMPER_REJECTED=OK")


if __name__ == "__main__":
    main()
