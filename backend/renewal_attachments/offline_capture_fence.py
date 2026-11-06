"""Control experimental de consistencia de captura.

No establece una barrera de escritura ni autoriza
una restauración. Solo valida evidencias de captura.
"""
import hashlib
import hmac
import json
import re


class CaptureConsistencyError(Exception):
    pass


IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")
DIGEST = re.compile(r"[0-9a-f]{64}\Z")


def _digest(value):
    return hashlib.sha256(value).hexdigest()


def _canonical(value):
    return json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
    ).encode()


def verify_capture_fence(
    *,
    before,
    after,
    database_inventory,
    object_inventory,
):
    """Rechaza capturas cuya evidencia no sea coherente.

    before/after son marcadores obtenidos por un
    coordinador externo de escritura.

    Este control NO puede demostrar que el coordinador
    haya impedido escrituras durante la captura.
    """
    try:
        for marker in (before, after):
            if (
                not isinstance(marker, dict)
                or set(marker) != {
                    "epoch",
                    "snapshot",
                    "inventory_digest",
                }
            ):
                raise ValueError("invalid marker")

            if (
                type(marker["epoch"]) is not int
                or marker["epoch"] < 0
                or not isinstance(marker["snapshot"], str)
                or not IDENTIFIER.fullmatch(
                    marker["snapshot"]
                )
                or not isinstance(
                    marker["inventory_digest"], str
                )
                or not DIGEST.fullmatch(
                    marker["inventory_digest"]
                )
            ):
                raise ValueError("invalid marker values")

        if before != after:
            raise ValueError("capture markers changed")

        if (
            not isinstance(database_inventory, dict)
            or not isinstance(object_inventory, dict)
            or set(database_inventory)
            != set(object_inventory)
        ):
            raise ValueError("different inventories")

        if len(database_inventory) > 10000:
            raise ValueError("inventory exceeds limit")

        for identifier, digest in database_inventory.items():
            if (
                not isinstance(identifier, str)
                or not re.fullmatch(
                    r"[0-9a-f]{32}", identifier
                )
                or not isinstance(digest, str)
                or not DIGEST.fullmatch(digest)
                or not isinstance(
                    object_inventory[identifier], str
                )
                or not hmac.compare_digest(
                    digest,
                    object_inventory[identifier]
                )
            ):
                raise ValueError("object mismatch")

        actual_digest = _digest(
            _canonical(database_inventory)
        )

        if not hmac.compare_digest(
            actual_digest,
            before["inventory_digest"],
        ):
            raise ValueError("inventory marker mismatch")

        return {
            "consistent": True,
            "snapshot": before["snapshot"],
            "epoch": before["epoch"],
            "objects": len(database_inventory),
            "release_authorized": False,
        }

    except (
        ValueError,
        TypeError,
        KeyError,
        AttributeError,
    ) as exc:
        raise CaptureConsistencyError(
            "CAPTURE_NOT_CONSISTENT"
        ) from exc
