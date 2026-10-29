"""B13E: contrato v3 con identidad de clave firmada.

Solo ensayos. El receptor nunca firma ni libera documentos.
"""
import json
from datetime import datetime, timezone

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
    Ed25519PublicKey,
)
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import transaction

from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_write_barrier_b06b import advisory_barrier
from .offline_key_registry_b13d import (
    KEY_ID, resolve_public_key,
)
from .offline_ed25519_b13b import (
    canonical, issue_verdict, DIGEST, SIGNATURE,
)

DOMAIN = b"VENCIRA-SCAN-ED25519-V3\x00"
FIELDS = {
    "version", "key_id", "object_key", "sha256",
    "verdict", "scanned_at", "engine",
}


def issue_keyed_verdict(
    *, private_key, key_id, attachment, engine, now=None,
):
    """Generador sintético; su clave privada no se persiste."""
    if (
        not isinstance(private_key, Ed25519PrivateKey)
        or type(key_id) is not str
        or not KEY_ID.fullmatch(key_id)
    ):
        raise ValueError("B13E_INVALID_SIGNER")
    base, _ = issue_verdict(
        private_key=private_key,
        attachment=attachment,
        engine=engine,
        now=now,
    )
    payload = {
        **base,
        "version": 3,
        "key_id": key_id,
    }
    signature = private_key.sign(
        DOMAIN + canonical(payload)
    ).hex()
    return payload, signature


def verify_keyed_verdict(
    *, payload, signature, registry, attachment, now=None,
):
    """Verificación fail-closed con clave pública aprobada."""
    if type(payload) is not dict or set(payload) != FIELDS:
        return False

    try:
        if (
            type(payload["version"]) is not int
            or payload["version"] != 3
            or type(payload["key_id"]) is not str
            or not KEY_ID.fullmatch(payload["key_id"])
            or type(payload["object_key"]) is not str
            or payload["object_key"] != str(attachment.storage_key)
            or type(payload["sha256"]) is not str
            or not DIGEST.fullmatch(payload["sha256"])
            or payload["sha256"] != attachment.sha256
            or type(payload["verdict"]) is not str
            or payload["verdict"] != "clean"
            or type(payload["scanned_at"]) is not int
            or type(payload["engine"]) is not str
            or not 1 <= len(payload["engine"]) <= 80
            or not payload["engine"].isascii()
            or attachment.state != "quarantined"
            or type(signature) is not str
            or not SIGNATURE.fullmatch(signature)
        ):
            return False

        instant = now if now is not None else datetime.now(timezone.utc)
        if (
            not isinstance(instant, datetime)
            or instant.tzinfo is None
            or instant.utcoffset() is None
        ):
            return False

        age = int(instant.timestamp()) - payload["scanned_at"]
        if not -30 <= age <= 600:
            return False

        public_key = resolve_public_key(
            registry=registry,
            key_id=payload["key_id"],
            now=instant,
        )
        Ed25519PublicKey.from_public_bytes(
            public_key
        ).verify(
            bytes.fromhex(signature),
            DOMAIN + canonical(payload),
        )
        return True

    except (
        PermissionDenied, InvalidSignature,
        ValueError, TypeError, KeyError,
        AttributeError, OverflowError, UnicodeError,
    ):
        return False


def persist_keyed_v3_offline(
    *, attachment_id, payload, signature, registry,
    expected_fingerprint, now=None,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B13E_TEST_ONLY")

    if (
        type(expected_fingerprint) is not tuple
        or len(expected_fingerprint) != 6
    ):
        raise PermissionDenied("B13E_INVALID_FINGERPRINT")

    with advisory_barrier(capture=False):
        with transaction.atomic():
            attachment = (
                RenewalAttachment.objects
                .select_for_update()
                .get(pk=attachment_id)
            )
            fields = (
                "storage_key", "sha256", "byte_size",
                "state", "display_name", "content_type",
            )
            current = tuple(
                getattr(attachment, field) for field in fields
            )
            if current != expected_fingerprint:
                raise PermissionDenied("B13E_METADATA_CHANGED")

            if AttachmentScanEvidence.objects.filter(
                attachment=attachment
            ).exists():
                raise PermissionDenied("B13E_DUPLICATE")

            if not verify_keyed_verdict(
                payload=payload,
                signature=signature,
                registry=registry,
                attachment=attachment,
                now=now,
            ):
                raise PermissionDenied("B13E_INVALID_EVIDENCE")

            return AttachmentScanEvidence.objects.create(
                attachment=attachment,
                payload=payload,
                signature=signature,
            )
