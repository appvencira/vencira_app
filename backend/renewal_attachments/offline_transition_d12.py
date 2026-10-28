"""D12: conciliación histórica, exclusivamente en PG17 de ensayo.

No copia, elimina, reinterpreta ni publica registros.
"""
from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection, transaction

from reminders.models import RenewalAttachment as Historical
from .models import RenewalAttachment as Independent

FIELDS = (
    "id", "renewal_id", "uploaded_by_id",
    "display_name", "content_type", "byte_size",
    "sha256", "storage_key", "state", "created_at",
)


def inspect_transition_d12():
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings, "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
        or connection.in_atomic_block
    ):
        raise PermissionDenied("PG17_ISOLATED_ONLY")

    with transaction.atomic():
        # Se fija antes de la primera consulta para obtener
        # la misma instantánea en las dos tablas.
        with connection.cursor() as cursor:
            cursor.execute(
                "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, "
                "READ ONLY"
            )

        old = {
            row["id"]: row
            for row in Historical.objects.values(*FIELDS)
        }
        new = {
            row["id"]: row
            for row in Independent.objects.values(*FIELDS)
        }

    old_keys, new_keys = set(old), set(new)
    common = old_keys & new_keys

    mismatched = sum(
        any(old[key][field] != new[key][field] for field in FIELDS)
        for key in common
    )

    result = {
        "historical_count": len(old),
        "independent_count": len(new),
        "historical_only": len(old_keys - new_keys),
        "independent_only": len(new_keys - old_keys),
        "matching": len(common) - mismatched,
        "mismatched": mismatched,
        "empty": not old and not new,
        "release_authorized": False,
    }
    result["requires_review"] = bool(
        result["historical_only"]
        or result["independent_only"]
        or result["mismatched"]
    )
    # No devolver identificadores ni información personal.
    return result
