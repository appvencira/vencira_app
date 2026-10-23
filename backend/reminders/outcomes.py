"""O3: explicit business outcomes on external-policy annotations only.

Never sends notices, creates a global customer identity or mutates another tenant.
"""
import calendar
from datetime import date, timedelta

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import (
    ReminderCandidate, ReminderPolicy, Renewal, RenewalAuditEvent,
    RenewalFollowUp, RenewalOutcome,
)
from .views import _membership, _visible_renewals


def _next_year(day):
    """Retain month and civil day, clamping 29 February to 28 if needed."""
    year = day.year + 1
    return date(year, day.month,
                min(day.day, calendar.monthrange(year, day.month)[1]))


def _parse_day(value):
    if not isinstance(value, str) or len(value) != 10:
        return None
    try:
        parsed = date.fromisoformat(value)
    except (TypeError, ValueError):
        return None
    return parsed if parsed.isoformat() == value and 2000 <= parsed.year <= 2100 else None


def _cancel_plans(renewal, user):
    """Keep past rows for evidence; never delete O2/candidate history."""
    RenewalFollowUp.objects.filter(
        renewal=renewal, state=RenewalFollowUp.State.PLANNED,
    ).update(state=RenewalFollowUp.State.CANCELLED, closed_by=user,
             updated_at=timezone.now())
    ReminderCandidate.objects.filter(
        renewal=renewal, state=ReminderCandidate.State.PLANNED,
    ).update(state=ReminderCandidate.State.CANCELLED, updated_at=timezone.now())


def _rebuild_candidates(renewal):
    """Materialise enabled policies after one-year deferral or archive restore.

    A policy is only a *planned* candidate. Never infer an actual delivery.
    """
    policies = ReminderPolicy.objects.filter(
        workspace_id=renewal.workspace_id, enabled=True,
    )
    for policy in policies:
        basis = (renewal.expires_on if policy.basis == ReminderPolicy.Basis.EXPIRY
                 else renewal.notice_deadline_on)
        if basis is None:
            continue
        planned = basis - timedelta(days=policy.days_before)
        ReminderCandidate.objects.update_or_create(
            renewal=renewal, policy=policy, scheduled_for=planned,
            defaults={"state": ReminderCandidate.State.PLANNED},
        )


def _publish(renewal, actor, kind, *, previous=None, current=None,
             follow_up=None, previous_entry=""):
    event = RenewalOutcome.objects.create(
        renewal=renewal, actor=actor, kind=kind,
        previous_expiry=previous, new_expiry=current,
        follow_up_for=follow_up, previous_entry=previous_entry or "",
    )
    fields = ["outcome"]
    if previous != current and previous is not None:
        fields.append("expires_on")
    if follow_up is not None:
        fields.append("manual_follow_up")
    if kind in (RenewalOutcome.Kind.WON, RenewalOutcome.Kind.DISCARDED,
                RenewalOutcome.Kind.RESTORED):
        fields += ["status", "archived_at", "archive_outcome"]
    RenewalAuditEvent.objects.create(
        workspace=renewal.workspace, renewal=renewal, actor=actor,
        action=RenewalAuditEvent.Action.UPDATED, changed_fields=fields,
        metadata={"outcome": {
            "kind": kind,
            "previous_expiry": previous.isoformat() if previous else None,
            "new_expiry": current.isoformat() if current else None,
            "follow_up_for": follow_up.isoformat() if follow_up else None,
        }},
    )
    return event


def _event_payload(event):
    return {
        "id": str(event.pk), "kind": event.kind,
        "timestamp": event.created_at.isoformat(),
        "previous_expiry": event.previous_expiry.isoformat()
            if event.previous_expiry else None,
        "new_expiry": event.new_expiry.isoformat()
            if event.new_expiry else None,
        "follow_up_for": event.follow_up_for.isoformat()
            if event.follow_up_for else None,
    }


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def renewal_outcomes(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    visible = _visible_renewals(membership)

    if request.method == "GET":
        renewal = get_object_or_404(visible, pk=renewal_id)
        events = RenewalOutcome.objects.filter(renewal=renewal)[:50]
        response = Response({"results": [_event_payload(item) for item in events]})
        response["Cache-Control"] = "no-store"
        return response

    if not isinstance(request.data, dict) or "kind" not in request.data:
        return Response({"kind": "Desenlace obligatorio."},
                        status=status.HTTP_400_BAD_REQUEST)
    kind = request.data["kind"]
    kinds = {k for k, _ in RenewalOutcome.Kind.choices}
    if kind not in kinds:
        return Response({"kind": "Desenlace desconocido."},
                        status=status.HTTP_400_BAD_REQUEST)
    expected_keys = ({"kind", "scheduled_for"}
                     if kind == RenewalOutcome.Kind.UNDECIDED else {"kind"})
    if set(request.data) != expected_keys:
        return Response({"fields": "Parámetros no permitidos o incompletos."},
                        status=status.HTTP_400_BAD_REQUEST)
    follow_date = (_parse_day(request.data["scheduled_for"])
                   if kind == RenewalOutcome.Kind.UNDECIDED else None)
    if kind == RenewalOutcome.Kind.UNDECIDED and follow_date is None:
        return Response({"scheduled_for": "Fecha civil inválida."},
                        status=status.HTTP_400_BAD_REQUEST)

    with transaction.atomic():
        renewal = get_object_or_404(
            visible.select_for_update(), pk=renewal_id,
        )
        if kind == RenewalOutcome.Kind.RESTORED:
            if renewal.archived_at is None or renewal.archive_outcome not in (
                    RenewalOutcome.Kind.WON, RenewalOutcome.Kind.DISCARDED):
                return Response({"detail": "No está en el archivo."},
                                status=status.HTTP_409_CONFLICT)
            earlier = RenewalOutcome.objects.filter(
                renewal=renewal, kind=renewal.archive_outcome,
            ).first()
            if renewal.archive_outcome == RenewalOutcome.Kind.WON and earlier:
                # Revert local entry conversion if it was a prospect before win.
                if earlier.previous_entry == Renewal.Entry.PROSPECTS:
                    renewal.entry = Renewal.Entry.PROSPECTS
            renewal.status = Renewal.Status.PENDING
            renewal.archived_at = None
            renewal.archive_outcome = ""
            renewal.save(update_fields=[
                "status", "archived_at", "archive_outcome", "entry", "updated_at",
            ])
            _rebuild_candidates(renewal)
            event = _publish(renewal, request.user, kind)
        else:
            if renewal.status == Renewal.Status.CLOSED or renewal.archived_at is not None:
                return Response({"detail": "La anotación ya está cerrada."},
                                status=status.HTTP_409_CONFLICT)
            if kind in (RenewalOutcome.Kind.WON, RenewalOutcome.Kind.DISCARDED):
                before_entry = renewal.entry or ""
                renewal.status = Renewal.Status.CLOSED
                renewal.archive_outcome = kind
                renewal.archived_at = timezone.now()
                if kind == RenewalOutcome.Kind.WON and renewal.entry == Renewal.Entry.PROSPECTS:
                    # This is per external policy annotation, NOT a CRM-wide mutation.
                    renewal.entry = Renewal.Entry.CLIENTS
                renewal.save(update_fields=[
                    "status", "archive_outcome", "archived_at", "entry", "updated_at",
                ])
                _cancel_plans(renewal, request.user)
                event = _publish(renewal, request.user, kind,
                                 previous_entry=before_entry)
            elif kind == RenewalOutcome.Kind.DECLINED:
                try:
                    next_expiry = _next_year(renewal.expires_on)
                    next_notice = (_next_year(renewal.notice_deadline_on)
                                   if renewal.notice_deadline_on else None)
                except (ValueError, OverflowError):
                    return Response({"detail": "Vencimiento fuera de rango."},
                                    status=status.HTTP_400_BAD_REQUEST)
                old = renewal.expires_on
                _cancel_plans(renewal, request.user)
                renewal.expires_on = next_expiry
                renewal.notice_deadline_on = next_notice
                renewal.status = Renewal.Status.PENDING
                renewal.save(update_fields=[
                    "expires_on", "notice_deadline_on", "status", "updated_at",
                ])
                _rebuild_candidates(renewal)
                event = _publish(renewal, request.user, kind,
                                 previous=old, current=next_expiry)
            else:
                # 'Aún sin decidir': follow-up is part of ONE transaction.
                prior = RenewalFollowUp.objects.select_for_update().filter(
                    renewal=renewal, state=RenewalFollowUp.State.PLANNED,
                ).first()
                if prior is not None:
                    prior.state = RenewalFollowUp.State.CANCELLED
                    prior.closed_by = request.user
                    prior.save(update_fields=["state", "closed_by", "updated_at"])
                RenewalFollowUp.objects.create(
                    renewal=renewal, scheduled_for=follow_date,
                    created_by=request.user,
                )
                event = _publish(renewal, request.user, kind,
                                 follow_up=follow_date)
    response = Response({"event": _event_payload(event)},
                        status=status.HTTP_201_CREATED)
    response["Cache-Control"] = "no-store"
    return response
