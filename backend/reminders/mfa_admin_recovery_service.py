"""D1.5-S1: aprobación interna auditada; NUNCA restablece MFA.

No expuesta por API ni comando. La custodia operacional externa sigue pendiente.
"""
from datetime import timedelta
from django.conf import settings
from django.db import transaction
from django.utils import timezone
from django.contrib.auth import get_user_model
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
    if not isinstance(reviewer_ids, (tuple, frozenset)) or len(set(reviewer_ids)) < 2:
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
    if (case.created_at > now or case.expires_at <= now
            or now - case.created_at > timedelta(hours=72)):
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
    if case.expires_at <= now:
        return False, "CASE_EXPIRED"
    approvals = tuple(case.approvals.all())
    if any(item.reviewer_id not in roster for item in approvals):
        return False, "REVIEWER_NOT_AUTHORIZED"
    eligible = set(get_user_model().objects.filter(
        pk__in=[item.reviewer_id for item in approvals],
        is_active=True, is_staff=True,
    ).values_list("pk", flat=True))
    if any(item.reviewer_id not in eligible for item in approvals):
        return False, "REVIEWER_NOT_ELIGIBLE"
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


@transaction.atomic
def cancel_recovery_case(*, case_id, actor):
    """Cancela un caso pendiente sin tocar sesiones, secretos ni factores MFA.

    Solo puede solicitarlo el titular o el solicitante persistidos. La
    operación es terminal y serializada mediante bloqueo de fila.
    """
    case = Case.objects.select_for_update().get(pk=case_id)
    if not actor or not actor.pk or not actor.is_active:
        return False, "ACTOR_NOT_ELIGIBLE"
    if actor.pk not in (case.subject_id, case.requester_id):
        return False, "ACTOR_NOT_AUTHORIZED"
    if case.status == Case.Status.CANCELLED:
        return True, "ALREADY_CANCELLED"
    if case.status != Case.Status.PENDING:
        return False, "CASE_NOT_PENDING"
    case.status = Case.Status.CANCELLED
    case.save(update_fields=["status"])
    Event.objects.create(case=case, actor=actor, action="cancelled")
    return True, "CASE_CANCELLED"


@transaction.atomic
def expire_recovery_case(*, case_id, actor, now=None):
    """Expira un caso vencido y audita una sola transición.

    La operación requiere operador de plantilla activa; jamás altera factores,
    cookies, sesiones o contraseñas. No existe endpoint público.
    """
    now = timezone.now() if now is None else now
    if not actor or not actor.pk or not actor.is_active or not actor.is_staff:
        return False, "ACTOR_NOT_ELIGIBLE"
    case = Case.objects.select_for_update().get(pk=case_id)
    if case.status == Case.Status.EXPIRED:
        return True, "ALREADY_EXPIRED"
    if case.status != Case.Status.PENDING:
        return False, "CASE_NOT_PENDING"
    if now < case.expires_at and now <= case.created_at + timedelta(hours=72):
        return False, "CASE_NOT_EXPIRED"
    case.status = Case.Status.EXPIRED
    case.save(update_fields=["status"])
    Event.objects.create(case=case, actor=actor, action="expired")
    return True, "CASE_EXPIRED"

@transaction.atomic
def open_recovery_case(*, subject_id, requester):
    """Abre expediente interno sin tocar ni revelar factores.

    Solo el titular activo puede solicitarlo a través de esta primitiva.
    La capa de transporte deberá verificar identidad reciente y canal externo
    antes de estar autorizada a invocarla. No hay endpoint publicado.
    """
    # Comprobar atribución antes de consultar canales externos.
    if not requester or not requester.pk or not requester.is_active or requester.pk != subject_id:
        return None, "REQUESTER_NOT_AUTHORIZED"
    User = get_user_model()
    subject = User.objects.select_for_update().get(pk=subject_id)
    if not subject.is_active:
        return None, "REQUESTER_NOT_AUTHORIZED"
    verifier = getattr(settings, "VENCIRA_MFA_RECOVERY_IDENTITY_VERIFIER", None)
    if not callable(verifier):
        return None, "INDEPENDENT_IDENTITY_VERIFIER_REQUIRED"
    try:
        verified = verifier(subject_id=subject_id, requester=requester)
    except Exception:
        # Error del verificador: nunca abrir expediente ni revocar sesiones.
        return None, "INDEPENDENT_IDENTITY_VERIFICATION_UNAVAILABLE"
    if verified is not True:
        return None, "INDEPENDENT_IDENTITY_NOT_VERIFIED"
    from .models import UserMfaState
    state = UserMfaState.objects.select_for_update().filter(user_id=subject_id).first()
    if state is None or not state.enabled:
        return None, "ACTIVE_MFA_REQUIRED"
    if Case.objects.filter(subject_id=subject_id, status=Case.Status.PENDING).exists():
        return None, "CASE_ALREADY_PENDING"
    now = timezone.now()
    case = Case.objects.create(
        subject=subject, requester=requester,
        quarantine_until=now + timedelta(hours=24),
        expires_at=now + timedelta(hours=72),
    )
    state.session_epoch += 1
    state.save(update_fields=["session_epoch", "updated_at"])
    Event.objects.create(case=case, actor=requester, action="opened")
    return case.pk, "CASE_OPENED_RESTRICTED"


def inspect_external_execution_evidence(*, case_id):
    """Solo consulta: un veredicto interno nunca autoriza sustitución MFA."""
    allowed, reason = inspect_recovery_preconditions(case_id=case_id)
    if not allowed:
        return False, reason
    verifier = getattr(settings, "VENCIRA_MFA_RECOVERY_EXECUTION_VERIFIER", None)
    if not callable(verifier):
        return False, "EXTERNAL_EXECUTION_VERIFIER_REQUIRED"
    try:
        checked = verifier(case_id=case_id)
    except Exception:
        return False, "EXTERNAL_EXECUTION_VERIFIER_UNAVAILABLE"
    if checked is not True:
        return False, "EXTERNAL_EXECUTION_EVIDENCE_REJECTED"
    return True, "PRECONDITIONS_ONLY"


@transaction.atomic
def prepare_administrative_factor(*, case_id, keys):
    """Prepara un TOTP aislado; nunca toca el factor MFA activo.

    Primitiva interna sin endpoint. Exige evidencia externa y doble revisión
    en cada invocación; el nuevo secreto solo puede entregarse al titular por
    un canal protegido todavía no implementado.
    """
    from .models import UserMfaState, UserMfaPendingRotationCode
    from .mfa_secrets import encrypt_totp_secret
    from .mfa_totp import generate_secret

    case = Case.objects.select_for_update().get(pk=case_id)
    state = UserMfaState.objects.select_for_update().get(user_id=case.subject_id)
    allowed, _ = inspect_external_execution_evidence(case_id=case_id)
    if not allowed or not state.enabled:
        return None
    now = timezone.now()
    if state.locked_until and state.locked_until > now:
        return None
    if state.pending_rotation_secret and state.pending_rotation_expires_at and state.pending_rotation_expires_at > now:
        return None
    secret = generate_secret()
    state.pending_rotation_secret = encrypt_totp_secret(
        secret, user_id=case.subject_id, keys=keys,
    )
    state.pending_rotation_expires_at = min(now + timedelta(minutes=10), case.expires_at)
    state.pending_administrative_case_id = case.pk
    UserMfaPendingRotationCode.objects.filter(state=state).delete()
    state.save(update_fields=["pending_rotation_secret", "pending_rotation_expires_at", "pending_administrative_case_id", "updated_at"])
    Event.objects.create(case=case, actor_id=case.requester_id, action="factor_prepared")
    return secret
