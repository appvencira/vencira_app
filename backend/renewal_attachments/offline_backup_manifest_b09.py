"""B09: manifiesto autenticado y retención en simulación.

No accede a disco, repositorios, O5 ni infraestructura real.
La autenticidad requiere una clave independiente y custodiada.
"""
import hashlib
import hmac
import json
import re
from datetime import date


class BackupManifestError(Exception):
    pass


IDENT = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
SHA = re.compile(r"[0-9a-f]{64}\Z")


def canonical(data):
    return json.dumps(
        data, sort_keys=True,
        separators=(",", ":"), ensure_ascii=True
    ).encode("utf-8")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def _identifier(value):
    if type(value) is not str or not IDENT.fullmatch(value):
        raise BackupManifestError("INVALID_IDENTITY")


def _key(key):
    if type(key) is not bytes or len(key) < 32:
        raise BackupManifestError("INVALID_AUTHENTICATION_KEY")


def _manifest_fields(payload):
    if not isinstance(payload, dict) or set(payload) != {
        "version", "snapshot_id", "database_key_id",
        "attachment_key_id", "manifest_key_id",
        "database_sha256", "attachments_sha256"
    }:
        raise BackupManifestError("INVALID_MANIFEST")

    if type(payload["version"]) is not int or payload["version"] != 1:
        raise BackupManifestError("INVALID_VERSION")

    for field in (
        "snapshot_id", "database_key_id",
        "attachment_key_id", "manifest_key_id",
    ):
        _identifier(payload[field])

    for field in ("database_sha256", "attachments_sha256"):
        if type(payload[field]) is not str or not SHA.fullmatch(
            payload[field]
        ):
            raise BackupManifestError("INVALID_DIGEST")


def create_manifest(
    *, database_envelope, attachment_bundle,
    snapshot_id, database_key_id,
    attachment_key_id, manifest_key_id,
    authentication_key,
):
    _key(authentication_key)

    for item in (database_envelope, attachment_bundle):
        if type(item) is not bytes or not 0 < len(item) <= 48 * 1024 * 1024:
            raise BackupManifestError("INVALID_OBJECT")

    payload = {
        "version": 1,
        "snapshot_id": snapshot_id,
        "database_key_id": database_key_id,
        "attachment_key_id": attachment_key_id,
        "manifest_key_id": manifest_key_id,
        "database_sha256": digest(database_envelope),
        "attachments_sha256": digest(attachment_bundle),
    }
    _manifest_fields(payload)

    mac = hmac.new(
        authentication_key, canonical(payload), hashlib.sha256
    ).hexdigest()

    return canonical({"payload": payload, "hmac_sha256": mac})


def verify_manifest(
    *, manifest, database_envelope, attachment_bundle,
    expected_snapshot_id, expected_database_key_id,
    expected_attachment_key_id, expected_manifest_key_id,
    authentication_key,
):
    try:
        _key(authentication_key)
        if type(manifest) is not bytes or not 0 < len(manifest) < 4096:
            raise ValueError("bad size")

        container = json.loads(manifest)
        if type(container) is not dict or set(container) != {
            "payload", "hmac_sha256"
        }:
            raise ValueError("bad container")

        payload = container["payload"]
        _manifest_fields(payload)

        actual_mac = container["hmac_sha256"]
        if type(actual_mac) is not str or not SHA.fullmatch(actual_mac):
            raise ValueError("bad mac")

        expected_mac = hmac.new(
            authentication_key, canonical(payload), hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(actual_mac, expected_mac):
            raise ValueError("manifest authentication failed")

        expected_ids = (
            (payload["snapshot_id"], expected_snapshot_id),
            (payload["database_key_id"], expected_database_key_id),
            (payload["attachment_key_id"], expected_attachment_key_id),
            (payload["manifest_key_id"], expected_manifest_key_id),
        )
        for actual, expected in expected_ids:
            if type(expected) is not str or not hmac.compare_digest(
                actual, expected
            ):
                raise ValueError("identity mismatch")

        for data, field in (
            (database_envelope, "database_sha256"),
            (attachment_bundle, "attachments_sha256"),
        ):
            if type(data) is not bytes or not hmac.compare_digest(
                digest(data), payload[field]
            ):
                raise ValueError("object mismatch")

        return {
            "verified": True,
            "snapshot_id": expected_snapshot_id,
            "release_authorized": False,
        }

    except (
        ValueError, TypeError, KeyError, AttributeError,
        UnicodeError, BackupManifestError,
    ) as exc:
        raise BackupManifestError(
            "BACKUP_SET_VERIFICATION_FAILED"
        ) from exc


def plan_retention(*, snapshots, today, keep_days=30, keep_minimum=2):
    """Plan no destructivo: nunca ejecuta eliminaciones.

    Solo una copia verificada y recuperable puede contar
    para el mínimo protegido. Deberá probarse restauración
    real antes de producir una orden de eliminación.
    """
    if (
        type(today) is not date
        or type(keep_days) is not int or not 1 <= keep_days <= 3650
        or type(keep_minimum) is not int
        or not 2 <= keep_minimum <= 100
        or type(snapshots) not in (tuple, list)
        or len(snapshots) > 10000
    ):
        raise BackupManifestError("INVALID_RETENTION_POLICY")

    ids = set()
    validated = []
    for item in snapshots:
        if type(item) is not dict or set(item) != {
            "id", "created_on", "verified", "recoverable"
        }:
            raise BackupManifestError("INVALID_SNAPSHOT")
        _identifier(item["id"])
        if item["id"] in ids or type(item["created_on"]) is not date:
            raise BackupManifestError("INVALID_SNAPSHOT")
        if item["created_on"] > today:
            raise BackupManifestError("FUTURE_SNAPSHOT")
        if (
            type(item["verified"]) is not bool
            or type(item["recoverable"]) is not bool
        ):
            raise BackupManifestError("INVALID_SNAPSHOT")
        ids.add(item["id"])
        validated.append(item)

    ordered = sorted(
        validated,
        key=lambda x: (x["created_on"], x["id"]),
        reverse=True
    )
    reliable = [
        item for item in ordered
        if item["verified"] and item["recoverable"]
    ]

    # Si no hay suficientes recuperables, no se propone
    # ningún borrado.
    if len(reliable) < keep_minimum:
        return {
            "retain": [x["id"] for x in ordered],
            "eligible_for_manual_review": [],
            "deletion_authorized": False,
            "requires_review": True,
        }

    protected = {x["id"] for x in reliable[:keep_minimum]}
    retained = []
    candidates = []
    for item in ordered:
        age = (today - item["created_on"]).days
        if (
            item["id"] not in protected
            and age > keep_days
            and item["verified"]
            and item["recoverable"]
        ):
            candidates.append(item["id"])
        else:
            retained.append(item["id"])

    return {
        "retain": retained,
        "eligible_for_manual_review": candidates,
        "deletion_authorized": False,
        "requires_review": bool(candidates),
    }
