"""Whitepaper §11: resultados agregados de pólizas externas, solo escritorio.

Cuenta actos de cierre del periodo (no estados actuales) y trabajo pendiente
por vencimiento. No incluye PII ni simula avisos enviados.
"""
from datetime import date, datetime, time
import re
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db.models import Count
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Renewal, RenewalOutcome, WorkspaceMember
from .views import _membership, _visible_renewals


def _interval(params):
    """Periodo civil inclusivo/exclusivo: mes, trimestre o año, 2000–2100."""
    keys = set(params.keys())
    period = params.get("period", "")
    if period not in ("month", "quarter", "year"):
        return None
    required = {"period", "year"}
    if period in ("month", "quarter"):
        required.add(period)
    if keys != required or any(len(params.getlist(key)) != 1 for key in required):
        return None
    raw_year = params.get("year", "")
    if not re.fullmatch(r"(?:20\d\d|2100)", raw_year):
        return None
    year = int(raw_year)
    if period == "year":
        start = date(year, 1, 1)
        finish = date(year + 1, 1, 1)
    else:
        field = params.get(period, "")
        upper = 12 if period == "month" else 4
        if not re.fullmatch(r"[1-9]|1[0-2]", field) or int(field) > upper:
            return None
        first_month = int(field) if period == "month" else 3 * (int(field) - 1) + 1
        start = date(year, first_month, 1)
        next_month = first_month + (1 if period == "month" else 3)
        finish = date(year + (next_month > 12), ((next_month - 1) % 12) + 1, 1)
    return period, start, finish


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def results_summary(request, workspace_id):
    membership = _membership(request, workspace_id)
    # §18 deja pendiente el acceso de los empleados a resultados: fail-closed.
    if membership.role != WorkspaceMember.Role.OWNER:
        response = Response({"detail": "Solo administrador."},
                            status=status.HTTP_403_FORBIDDEN)
        response["Cache-Control"] = "no-store"
        return response
    window = _interval(request.query_params)
    if window is None:
        response = Response({"period": "Periodo no válido."},
                            status=status.HTTP_400_BAD_REQUEST)
        response["Cache-Control"] = "no-store"
        return response
    period, first, following = window
    # La zona horaria es fija por contrato del entorno español, no del host/UTC.
    tz = ZoneInfo(settings.TIME_ZONE)
    start = datetime.combine(first, time.min, tzinfo=tz)
    end = datetime.combine(following, time.min, tzinfo=tz)

    visible = _visible_renewals(membership)
    outcomes = (
        RenewalOutcome.objects.filter(
            renewal_id__in=visible.values("pk"),
            kind__in=("won", "declined", "discarded"),
            created_at__gte=start, created_at__lt=end,
        )
        .values("kind").annotate(total=Count("pk")).order_by()
    )
    counts = {"won": 0, "declined": 0, "discarded": 0}
    for item in outcomes:
        counts[item["kind"]] = item["total"]
    pending = visible.filter(
        expires_on__gte=first, expires_on__lt=following,
        archived_at__isnull=True,
    ).exclude(status=Renewal.Status.CLOSED).count()
    response = Response({
        "period": period,
        "from": first.isoformat(),
        "to_exclusive": following.isoformat(),
        "won": counts["won"],
        "declined": counts["declined"],
        "discarded": counts["discarded"],
        "pending": pending,
    })
    response["Cache-Control"] = "no-store"
    return response
