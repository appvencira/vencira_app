"""Solo lectura: historial de actuaciones de una ocurrencia interna.

Los eventos no acreditan envío de email, SMS o push. La autorización se
resuelve sobre la anotación antes de acceder al identificador de aviso.
"""
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.pagination import PageNumberPagination
from django.shortcuts import get_object_or_404

from .models import OperationalReminder, OperationalReminderEvent, WorkspaceMember
from .views import _membership, _visible_renewals


class EventPagination(PageNumberPagination):
    page_size = 30
    page_size_query_param = "page_size"
    max_page_size = 100


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def operational_reminder_history(request, workspace_id, renewal_id, reminder_id):
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(_visible_renewals(membership), pk=renewal_id)
    reminder = get_object_or_404(
        OperationalReminder, pk=reminder_id, renewal_id=renewal.pk)
    keys = set(request.query_params.keys())
    if (keys - {"page", "page_size"} or
            any(len(request.query_params.getlist(k)) != 1 for k in keys)):
        return Response({"detail": "Parámetros no válidos."}, status=400)
    for name in ("page", "page_size"):
        if name in keys:
            raw = request.query_params[name]
            if (len(raw) > 6 or not raw.isascii() or not raw.isdecimal() or
                    not 1 <= int(raw) <= 100000):
                return Response({name: "Número positivo inválido."}, status=400)

    qs = OperationalReminderEvent.objects.filter(
        reminder_id=reminder.pk).order_by("-occurred_at", "-id")
    paginator = EventPagination()
    page = paginator.paginate_queryset(qs, request)
    # No divulgar identificadores ni nombres de personas sin membresía actual.
    actor_ids = {row.actor_id for row in page if row.actor_id is not None}
    members = WorkspaceMember.objects.filter(
        workspace_id=workspace_id, user_id__in=actor_ids
    ).select_related("user")
    visible_actors = {member.user_id: member.user.get_username()
                      for member in members}
    data = [{
        "id": str(event.pk),
        "action": event.action,
        "previous_state": event.previous_state,
        "next_state": event.next_state,
        "scheduled_for": event.scheduled_for.isoformat(),
        "occurred_at": event.occurred_at.isoformat(),
        "actor": visible_actors.get(event.actor_id),
    } for event in page]
    response = paginator.get_paginated_response(data)
    response.data["delivery_status"] = "not_implemented"
    response["Cache-Control"] = "no-store"
    return response
