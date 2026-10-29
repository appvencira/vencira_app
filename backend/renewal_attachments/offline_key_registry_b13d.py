"""B13D: registro público de confianza, exclusivo de ensayos.

No contiene claves privadas ni concede acceso a documentos.
La política de revocación afecta a nuevas recepciones.
"""
import re
from dataclasses import dataclass
from datetime import datetime, timezone

from django.conf import settings
from django.core.exceptions import PermissionDenied

from .offline_ed25519_persistence_b13c import (
    persist_ed25519_evidence_offline,
)

KEY_ID = re.compile(r"[a-z0-9][a-z0-9._-]{0,63}\Z")


@dataclass(frozen=True)
class TrustedPublicKey:
    key_id: str
    public_key: bytes
    valid_from: datetime
    valid_until: datetime
    revoked: bool = False


def _aware_utc(instant):
    return (
        type(instant) is datetime
        and instant.tzinfo is not None
        and instant.utcoffset() is not None
    )


def resolve_public_key(*, registry, key_id, now=None):
    """Rechaza políticas ambiguas o claves caducadas."""
    if (
        type(registry) is not dict
        or type(key_id) is not str
        or not KEY_ID.fullmatch(key_id)
    ):
        raise PermissionDenied("B13D_INVALID_REGISTRY")

    instant = now if now is not None else datetime.now(timezone.utc)
    if not _aware_utc(instant):
        raise PermissionDenied("B13D_INVALID_TIME")

    entry = registry.get(key_id)

    if (
        type(entry) is not TrustedPublicKey
        or entry.key_id != key_id
        or type(entry.public_key) is not bytes
        or len(entry.public_key) != 32
        or type(entry.revoked) is not bool
        or not _aware_utc(entry.valid_from)
        or not _aware_utc(entry.valid_until)
        or entry.valid_from >= entry.valid_until
        or entry.revoked
        or not entry.valid_from <= instant < entry.valid_until
    ):
        raise PermissionDenied("B13D_KEY_NOT_TRUSTED")

    return entry.public_key


def persist_keyed_evidence_offline(
    *, registry, key_id, attachment_id,
    payload, signature, expected_fingerprint, now=None,
):
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
    ):
        raise PermissionDenied("B13D_TEST_ONLY")

    key = resolve_public_key(
        registry=registry,
        key_id=key_id,
        now=now,
    )

    return persist_ed25519_evidence_offline(
        attachment_id=attachment_id,
        payload=payload,
        signature=signature,
        public_key=key,
        expected_fingerprint=expected_fingerprint,
        now=now,
    )
