"""D1.5-S1C: aprobación interna auditada; NUNCA restablece MFA.

No expuesta por API ni comando. La elegibilidad actual exige cuentas de
personal activas; una política de doble control independiente sigue pendiente.
"""
from datetime import timedelta
from django.conf import settings
from django.db import transaction
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
    # Roster de despliegue, nunca proporcionado por la solicitud o su caller.
    reviewer_ids = getattr(settings, "VENCIRA_MFA_RECOVERY_REVIEWER_IDS", ())
    if not isinstance(reviewer_ids, (tuple, frozenset)) or len(reviewer_ids) < 2:
        return False, "REVIEWER_AUTHORIZATION_REQUIRED"
    case = Case.objects.select_for_update().get(pk=case_id)
    if not reviewer or not reviewer.pk or not reviewer.is_active or not reviewer.is_staff:
        return False, "REVIEWER_NOT_ELIGIBLE"
    if reviewer.pk not in reviewer_ids:
        return False, "REVIEWER_NOT_AUTHORIZED"
    if reviewer.pk in (case.requester_id, case.subject_id):
        return False, "REVIEWER_CONFLICT"
    if case.status != Case.Status.PENDING:
        return False, "CASE_NOT_PENDING"
    if case.created_at > now or case.expires_at <= now:
        return False, "CASE_EXPIRED"
    if case.channel_verified_at is None or case.channel_verified_at > now:
        return False, "INDEPENDENT_CHANNEL_NOT_VERIFIED"
    if case.quarantine_until < case.created_at + timedelta(hours=24):
        return False, "INVALID_QUARANTINE"
    if now < case.quarantine_until:
        return False, "QUARANTINE_ACTIVE"
    previous = Approval.objects.filter(case=case, reviewer=reviewer).first()
    if previous:
        if previous.expires_at <= now:
            return False, "APPROVAL_EXPIRED"
        return (True, "ALREADY_RECORDED") if approve else (False, "REVIEW_ALREADY_RECORDED")
    if not approve:
        case.status = Case.Status.REJECTED
        case.save(update_fields=["status"])
        Event.objects.create(case=case, actor=reviewer, action="rejected")
        return True, "REJECTED"
    # Una aprobación caducada no puede contarse como consentimiento actual.
    # No la borramos: es evidencia auditable y su existencia bloquea
    # nuevas aprobaciones de ese mismo revisor en este caso.
    if Approval.objects.filter(case=case, expires_at__lte=now).exists():
        return False, "EXPIRED_APPROVAL_IN_CASE"
    if case.approvals.count() >= 2:
        return False, "APPROVAL_LIMIT"
    Approval.objects.create(
        case=case, reviewer=reviewer, expires_at=min(now + APPROVAL_LIFETIME, case.expires_at),
    )
    Event.objects.create(case=case, actor=reviewer, action="review_approved")
    return True, "APPROVAL_RECORDED"


def inspect_recovery_preconditions(*, case_id, now=None):
    """Evaluación sin efectos. No concede permisos ni permite desactivar MFA.

    La verificación del canal externo y la identidad de custodios siguen
    requiriendo evidencia fuera de esta primitiva.
    """
    from .mfa_admin_recovery_policy import (
        RecoveryCase, RecoveryApproval, assess_recovery,
    )

    now = timezone.now() if now is None else now
    # La política se aplica al estado almacenado, no al payload del solicitante.
    case = Case.objects.prefetch_related("approvals").get(pk=case_id)
    roster = getattr(settings, "VENCIRA_MFA_RECOVERY_REVIEWER_IDS", ())
    if not isinstance(roster, (tuple, frozenset)) or len(set(roster)) < 2:
        return False, "REVIEWER_AUTHORIZATION_REQUIRED"
    approvals = tuple(case.approvals.all())
    if any(item.reviewer_id not in roster for item in approvals):
        return False, "REVIEWER_NOT_AUTHORIZED"
    verdict = RecoveryCase(
        case_id=str(case.pk),
        subject_id=case.subject_id,
        requester_id=case.requester_id,
        created_at=case.created_at,
        quarantine_until=case.quarantine_until,
        channel_verified=case.channel_verified_at is not None and case.channel_verified_at <= now,
        approvals=tuple(RecoveryApproval(
            reviewer_id=item.reviewer_id, case_id=str(case.pk),
            expires_at=item.expires_at,
        ) for item in approvals),
        status=case.status,
    )
    return assess_recovery(verdict, now=now)
