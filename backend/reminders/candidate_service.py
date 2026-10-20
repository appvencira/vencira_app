"""Prepara y concilia candidatos de aviso sin enviar mensajes ni datos fuera."""
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from .models import ReminderCandidate, ReminderPolicy, Renewal, Workspace


@transaction.atomic
def refresh_candidates(workspace_id, *, today=None, horizon_days=30):
    """Recalcula candidatos próximos para una sola organización.

    La organización se bloquea durante la conciliación para serializar
    ejecuciones concurrentes del mismo workspace. No toca avisos pasados.
    Sin canales de entrega ni trabajo en background.
    """
    if not isinstance(horizon_days, int) or not 0 <= horizon_days <= 365:
        raise ValueError("horizon_days debe estar entre 0 y 365")
    now = today if today is not None else timezone.localdate()
    through = now + timedelta(days=horizon_days)
    workspace = Workspace.objects.select_for_update().get(pk=workspace_id)
    policies = list(
        ReminderPolicy.objects.filter(workspace=workspace, enabled=True)
        .order_by("days_before", "id")
    )
    renewals = list(
        Renewal.objects.filter(
            workspace=workspace,
            status=Renewal.Status.PENDING,
            expires_on__gte=now,
            expires_on__lte=through + timedelta(days=365),
        ).only("id", "workspace_id", "expires_on")
    )

    current_ids = set()
    created = 0
    restored = 0
    for policy in policies:
        for renewal in renewals:
            scheduled = renewal.expires_on - timedelta(days=policy.days_before)
            if scheduled < now or scheduled > through:
                continue
            candidate, new = ReminderCandidate.objects.get_or_create(
                policy=policy,
                renewal=renewal,
                scheduled_for=scheduled,
                defaults={"state": ReminderCandidate.State.PLANNED},
            )
            current_ids.add(candidate.pk)
            if new:
                created += 1
            elif candidate.state == ReminderCandidate.State.CANCELLED:
                candidate.state = ReminderCandidate.State.PLANNED
                candidate.save(update_fields=["state", "updated_at"])
                restored += 1

    stale = ReminderCandidate.objects.filter(
        renewal__workspace=workspace,
        scheduled_for__gte=now,
        scheduled_for__lte=through,
        state=ReminderCandidate.State.PLANNED,
    ).exclude(pk__in=current_ids)
    cancelled = stale.update(state=ReminderCandidate.State.CANCELLED)
    return {"created": created, "restored": restored, "cancelled": cancelled}
