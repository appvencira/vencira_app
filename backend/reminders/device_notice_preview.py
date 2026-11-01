"""Authorized read-only source of candidate *device* notices.

This does NOT schedule a platform alarm, send a message, or claim delivery.
Native offline support needs its own secure local store and scheduling layer.
"""
from datetime import date, timedelta

from django.conf import settings
from rest_framework.decorators import api_view, permission_classes
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import OperationalReminder, Renewal
from .views import _membership, _visible_renewals

ACTIVE = (
    OperationalReminder.State.PLANNED,
    OperationalReminder.State.PENDING,
    OperationalReminder.State.SNOOZED,
)


class DeviceNoticePreviewPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = None


def _civil(raw):
    if type(raw) is not str or len(raw) != 10:
        raise ValueError("Fecha civil inválida")
    value = date.fromisoformat(raw)
    if value.isoformat() != raw or not 2000 <= value.year <= 2100:
        raise ValueError("Fecha civil inválida")
    return value


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def device_notice_preview(request, workspace_id):
    """Preview a bounded, authorized calendar; reads never cause delivery."""
    membership = _membership(request, workspace_id)
    params = request.query_params
    if (set(params) - {"from", "through", "page"} or
            len(params.getlist("from")) != 1 or
            len(params.getlist("through")) != 1 or
            len(params.getlist("page")) > 1):
        return Response({"detail": "Parámetros inválidos."}, status=400)
    try:
        start = _civil(params.get("from"))
        end = _civil(params.get("through"))
        # At most 31 consecutive civil days; no unbounded device export.
        if end < start or end - start > timedelta(days=30):
            raise ValueError("Se permiten hasta 31 días civiles.")
        if "page" in params:
            page = params["page"]
            if (len(page) > 6 or not page.isascii() or
                    not page.isdecimal() or not 1 <= int(page) <= 100000):
                raise ValueError("Página inválida")
    except (TypeError, ValueError, OverflowError) as exc:
        return Response({"detail": str(exc)}, status=400)

    visible = (_visible_renewals(membership)
        .filter(archived_at__isnull=True)
        .exclude(status=Renewal.Status.CLOSED))
    records = (OperationalReminder.objects
        .filter(renewal_id__in=visible.values("pk"),
                state__in=ACTIVE, scheduled_for__gte=start,
                scheduled_for__lte=end)
        .order_by("scheduled_for", "id"))
    paginator = DeviceNoticePreviewPagination()
    page = paginator.paginate_queryset(records, request)
    payload = [{
        "id": str(item.pk),
        "renewal_id": str(item.renewal_id),
        "scheduled_for": item.scheduled_for.isoformat(),
        "state": item.state,
        "reason": item.reason,
        "control_question": item.control_question,
        "generation": item.generation,
        "delivery_status": "not_implemented",
    } for item in page]
    response = paginator.get_paginated_response(payload)
    response.data.update({
        "from": start.isoformat(), "through": end.isoformat(),
        "timezone": settings.TIME_ZONE,
        "capabilities": {
            "native_alarm_scheduling": False,
            "offline_storage": False,
            "delivery": False,
        },
    })
    response["Cache-Control"] = "no-store"
    return response
