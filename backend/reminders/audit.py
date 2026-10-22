"""Registra eventos mínimos de vencimientos. Jamás almacena referencias de clientes."""
from .models import RenewalAuditEvent

AUDITABLE_FIELDS = ("customer_reference", "entry", "modality", "expires_on", "status", "notice_deadline_on", "assigned_to_id", "insurer_id", "full_name", "nickname", "phone", "email", "policy_number")


def make_audit_event(*, renewal, actor, before=None):
    """Se invoca DENTRO de la misma transacción de escritura de la API.

    El valor de customer_reference puede contener información personal:
    se registra solo el nombre de campo, nunca su contenido.
    """
    changed = [
        field for field in AUDITABLE_FIELDS
        if (before is None and (field not in ("notice_deadline_on", "assigned_to_id", "entry", "modality", "insurer_id") or bool(getattr(renewal, field))))
        or (before is not None and getattr(before, field) != getattr(renewal, field))
    ]
    # Jamás registrar valores de identidad en metadata.
    if not changed:
        return None
    metadata = {}
    for field in ("expires_on", "status", "notice_deadline_on"):
        if field in changed:
            prior = None if before is None else getattr(before, field)
            current = getattr(renewal, field)
            metadata[field] = {
                "before": str(prior) if prior is not None else None,
                "after": str(current) if current is not None else None,
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
