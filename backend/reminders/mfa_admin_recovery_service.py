"""D1.5-S1C: aprobación interna auditada; NUNCA restablece MFA.

No expuesta por API ni comando. La elegibilidad actual exige cuentas de
personal activas; una política de doble control independiente sigue pendiente.
"""
from datetime import timedelta
from django.db import transaction, IntegrityError
from django.utils import timezone
from .models import (
    MfaAdministrativeRecoveryCase as Case,
    MfaAdministrativeRecoveryApproval as Approval,
    MfaAdministrativeRecoveryEvent as Event,
)

APPROVAL_LIFETIME = timedelta(hours=1)


@transaction.atomic
def record_review(*, case_id, reviewer, approve: bool, now=None):
    """Registra una decisión con bloqueo de fila y respuesta idempotente.

    Esta primitiva no verifica identidad externa, NO permite ejecutar un reset
    ni afirma que el caso sea recuperable.
    """
    now = timezone.now() if now is None else now
    case = Case.objects.select_for_update().get(pk=case_id)
    if not reviewer or not reviewer.pk or not reviewer.is_active or not reviewer.is_staff:
        return False, "REVIEWER_NOT_ELIGIBLE"
    if reviewer.pk in (case.requester_id, case.subject_id):
        return False, "REVIEWER_CONFLICT"
    if case.status != Case.Status.PENDING:
        return False, "CASE_NOT_PENDING"
    if case.created_at > now or case.expires_at <= now:
        return False, "CASE_EXPIRED"
    if case.channel_verified_at is None or case.channel_verified_at > now:
        return False, "INDEPENDENT_CHANNEL_NOT_VERIFIED"
    if case.quarantine_until <= case.created_at:
        return False, "INVALID_QUARANTINE"
    previous = Approval.objects.filter(case=case, reviewer=reviewer).first()
    if previous:
        return True, "ALREADY_RECORDED" if approve else "REVIEW_ALREADY_RECORDED"
    if not approve:
        case.status = Case.Status.REJECTED
        case.save(update_fields=["status"])
        Event.objects.create(case=case, actor=reviewer, action="rejected")
        return True, "REJECTED"
    if case.approvals.count() >= 2:
        return False, "APPROVAL_LIMIT"
    Approval.objects.create(
        case=case, reviewer=reviewer, expires_at=min(now + APPROVAL_LIFETIME, case.expires_at),
    )
    Event.objects.create(case=case, actor=reviewer, action="review_approved")
    return True, "APPROVAL_RECORDED"
