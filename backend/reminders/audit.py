"""Registra eventos mínimos de vencimientos. Jamás almacena referencias de clientes."""
from .models import RenewalAuditEvent

AUDITABLE_FIELDS = ("customer_reference", "expires_on", "status")


def make_audit_event(*, renewal, actor, before=None):
    """Se invoca DENTRO de la misma transacción de escritura de la API.

    El valor de customer_reference puede contener información personal:
    se registra solo el nombre de campo, nunca su contenido.
    """
    changed = [
        field for field in AUDITABLE_FIELDS
        if before is None or getattr(before, field) != getattr(renewal, field)
    ]
    if not changed:
        return None
    metadata = {}
    for field in ("expires_on", "status"):
        if field in changed:
            metadata[field] = {
                "before": None if before is None else str(getattr(before, field)),
                "after": str(getattr(renewal, field)),
            }
    return RenewalAuditEvent.objects.create(
        workspace=renewal.workspace,
        renewal=renewal,
        actor=actor,
        action=(
            RenewalAuditEvent.Action.CREATED
            if before is None else RenewalAuditEvent.Action.UPDATED
        ),
        changed_fields=changed,
        metadata=metadata,
    )
