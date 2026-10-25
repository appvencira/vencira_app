"""Resumen mensual acotado por usuario/organización, sin exponer referencias."""
from datetime import date
import re

from django.db.models import Count
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import ReminderCandidate, ReminderPolicy, Renewal, RenewalFollowUp, WorkspaceMember, OperationalReminder
from .views import _membership, _visible_renewals
from .filtering import filtered_renewals


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def agenda_month(request, workspace_id):
    """Una agregación por tipo de evento y estado; nunca paginar 31 agendas."""
    membership = _membership(request, workspace_id)
    raw = request.query_params.get("month", "")
    if (set(request.query_params.keys()) - {"month", "entry", "modality", "insurer"} or
            len(request.query_params.getlist("month")) != 1):
        return Response({"month": "Parámetros no válidos."}, status=status.HTTP_400_BAD_REQUEST)
    if not re.fullmatch(r"(?:20\d\d|2100)-(?:0[1-9]|1[0-2])", raw):
        return Response(
            {"month": "Mes obligatorio en formato YYYY-MM (2000–2100)."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    year, month = map(int, raw.split("-"))
    first = date(year, month, 1)
    following = date(year + (month == 12), 1 if month == 12 else month + 1, 1)

    # Diccionario denso solo de días con actividad. La API nunca devuelve
    # referencias ni UUID de anotaciones individuales en el resumen mensual.
    days = {}

    def accumulate(day, kind, renewal_status, total):
        key = day.isoformat()
        record = days.setdefault(key, {
            "day": key,
            "expiry": {"pending": 0, "contacted": 0},
            "notice_deadline": {"pending": 0, "contacted": 0},
            "reminder": {"pending": 0, "contacted": 0},
            "follow_up": {"pending": 0, "contacted": 0},
        })
        record[kind][renewal_status] = total

    visible = filtered_renewals(request.query_params, _visible_renewals(membership)).exclude(status=Renewal.Status.CLOSED)
    for field, kind in (("expires_on", "expiry"), ("notice_deadline_on", "notice_deadline")):
        counts = (
            visible.filter(**{f"{field}__gte": first, f"{field}__lt": following})
            .values(field, "status")
            .annotate(total=Count("pk"))
            .order_by()
        )
        for row in counts:
            accumulate(row[field], kind, row["status"], row["total"])

    # Los candidatos repetidos para la misma anotación y día cuentan una
    # sola vez. No se interpreta ninguno como notificación entregada.
    candidates = ReminderCandidate.objects.filter(
        renewal__workspace_id=membership.workspace_id,
        renewal_id__in=visible.values("pk"),
        renewal__status__in=[Renewal.Status.PENDING, Renewal.Status.CONTACTED],
        state=ReminderCandidate.State.PLANNED,
        policy__enabled=True,
        scheduled_for__gte=first,
        scheduled_for__lt=following,
    )
    if membership.role != WorkspaceMember.Role.OWNER:
        candidates = candidates.filter(renewal__assigned_to_id=membership.user_id)

    # Unión exacta por anotación/día; no equivale a entrega.
    unique_due = set()
    for row in candidates.values(
        "scheduled_for", "renewal__status", "renewal_id"
    ).distinct():
        unique_due.add((row["scheduled_for"], row["renewal__status"], row["renewal_id"]))
    for row in OperationalReminder.objects.filter(
        renewal_id__in=visible.values("pk"),
        state__in=["planned", "pending", "snoozed"],
        scheduled_for__gte=first, scheduled_for__lt=following,
    ).values("scheduled_for", "renewal__status", "renewal_id").distinct():
        unique_due.add((row["scheduled_for"], row["renewal__status"], row["renewal_id"]))
    totals = {}
    for day, state, _ in unique_due:
        totals[(day, state)] = totals.get((day, state), 0) + 1
    for (day, state), count in totals.items():
        accumulate(day, "reminder", state, count)

    # Seguimientos manuales: nunca representan avisos automáticos ni entregados.
    # El conjunto de IDs ya está filtrado por membresía, asignación y filtros.
    for row in (
        RenewalFollowUp.objects.filter(
            renewal_id__in=visible.values("pk"),
            state=RenewalFollowUp.State.PLANNED,
            scheduled_for__gte=first, scheduled_for__lt=following,
        )
        .values("scheduled_for", "renewal__status")
        .annotate(total=Count("renewal_id", distinct=True))
        .order_by()
    ):
        accumulate(row["scheduled_for"], "follow_up",
                   row["renewal__status"], row["total"])

    response = Response({"month": raw, "days": [days[key] for key in sorted(days)]})
    response["Cache-Control"] = "no-store"
    return response
