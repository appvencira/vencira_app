"""Macrofase B: bandeja operativa de solo lectura.

Fecha civil explícita del cliente. Una lectura nunca reconcilia, envía, marca
como pendiente ni crea eventos. Solo ocurrencias internas realmente guardadas.
"""
from datetime import date
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response

from .models import OperationalReminder, Renewal
from .views import _membership, _visible_renewals


class InboxPagination(PageNumberPagination):
    page_size = 30
    page_size_query_param = "page_size"
    max_page_size = 100


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def operational_inbox(request, workspace_id):
    """Paginated occurrences for an authorized workspace, not delivery reports."""
    membership = _membership(request, workspace_id)
    keys = set(request.query_params.keys())
    if (keys - {"day", "scope", "page", "page_size"} or
            len(request.query_params.getlist("day")) != 1 or
            len(request.query_params.getlist("scope")) > 1 or
            len(request.query_params.getlist("page")) > 1 or
            len(request.query_params.getlist("page_size")) > 1):
        return Response({"detail": "Parámetros no válidos."},
                        status=status.HTTP_400_BAD_REQUEST)
    raw = request.query_params.get("day", "")
    try:
        day = date.fromisoformat(raw)
        if day.isoformat() != raw or not 2000 <= day.year <= 2100:
            raise ValueError()
    except (ValueError, TypeError):
        return Response({"day": "Fecha civil YYYY-MM-DD obligatoria."},
                        status=status.HTTP_400_BAD_REQUEST)

    scope = request.query_params.get("scope", "due")
    if scope not in ("due", "today", "overdue", "upcoming"):
        return Response({"scope": "Filtro inválido."},
                        status=status.HTTP_400_BAD_REQUEST)
    for name in ("page", "page_size"):
        if name in request.query_params:
            raw_value = request.query_params[name]
            if (len(raw_value) > 6 or not raw_value.isascii() or
                    not raw_value.isdecimal() or int(raw_value) < 1 or
                    int(raw_value) > 100000):
                return Response({name: "Número positivo inválido."},
                                status=status.HTTP_400_BAD_REQUEST)

    visible = _visible_renewals(membership).filter(
        archived_at__isnull=True).exclude(status=Renewal.Status.CLOSED)
    active = OperationalReminder.objects.filter(
        renewal_id__in=visible.values("pk"),
        state__in=["planned", "pending", "snoozed"],
    )
    # Contadores de ocurrencias, no número de pólizas ni de mensajes enviados.
    overdue_count = active.filter(scheduled_for__lt=day).count()
    today_count = active.filter(scheduled_for=day).count()
    upcoming_count = active.filter(scheduled_for__gt=day).count()
    if scope == "overdue":
        rows = active.filter(scheduled_for__lt=day)
    elif scope == "today":
        rows = active.filter(scheduled_for=day)
    elif scope == "upcoming":
        rows = active.filter(scheduled_for__gt=day)
    else:
        rows = active.filter(scheduled_for__lte=day)
    rows = rows.select_related("renewal").order_by("scheduled_for", "id")
    paginator = InboxPagination()
    page = paginator.paginate_queryset(rows, request)
    results = [{
        "id": str(r.pk),
        "renewal_id": str(r.renewal_id),
        "reference": r.renewal.customer_reference,
        "kind": r.kind,
        "scheduled_for": r.scheduled_for.isoformat(),
        "original_scheduled_for": r.original_scheduled_for.isoformat(),
        "reason": r.reason,
        "state": r.state,
        "control_question": r.control_question,
        "overdue": r.scheduled_for < day,
        "delivery_status": "not_implemented",
    } for r in page]
    response = paginator.get_paginated_response(results)
    response.data.update({
        "day": day.isoformat(), "scope": scope,
        "counts": {"overdue": overdue_count, "today": today_count,
                   "upcoming": upcoming_count},
    })
    response["Cache-Control"] = "no-store"
    return response
