"""API v1 con aislamiento y auditoría transaccional de escrituras."""
from datetime import date

from django.db import transaction
from django.db.models import Exists, OuterRef, Prefetch, Q, prefetch_related_objects
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .audit import make_audit_event
from .filtering import filtered_renewals
from .models import ReminderCandidate, Renewal, RenewalAuditEvent, WorkspaceMember
from .pagination import RenewalPagination
from .serializers import MembershipSerializer, RenewalSerializer


def _membership(request, workspace_id):
    # No revelar espacios ajenos a usuarios sin membresía.
    return get_object_or_404(
        WorkspaceMember.objects.select_related("workspace"),
        workspace_id=workspace_id,
        user=request.user,
    )


def _visible_renewals(membership):
    """Alcance autorizado antes de consultar, filtrar o bloquear filas."""
    scoped = Renewal.objects.filter(workspace_id=membership.workspace_id)
    if membership.role != WorkspaceMember.Role.OWNER:
        return scoped.filter(assigned_to_id=membership.user_id)
    return scoped


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    return Response({"id": request.user.pk, "username": request.user.get_username()})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def workspaces(request):
    memberships = WorkspaceMember.objects.filter(
        user=request.user
    ).select_related("workspace").order_by("workspace__name", "workspace_id")
    return Response(MembershipSerializer(memberships, many=True).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def workspace_members(request, workspace_id):
    """Información mínima para asignaciones del propietario, sin datos ajenos."""
    membership = _membership(request, workspace_id)
    if membership.role != WorkspaceMember.Role.OWNER:
        return Response({"detail": "No autorizado."},
                        status=status.HTTP_403_FORBIDDEN)
    members = WorkspaceMember.objects.filter(
        workspace_id=membership.workspace_id
    ).select_related("user").order_by("user__username", "user_id")
    return Response([
        {"id": row.user_id, "name": row.user.get_username(), "role": row.role}
        for row in members
    ])


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def agenda_day(request, workspace_id):
    """Vista de lectura: vencimientos, límites contractuales y avisos previstos.

    No presupone entrega real ni añade eventos "recuérdamelo" aún no modelados.
    El cliente envía el día local explícito; no usar la zona horaria del servidor.
    """
    membership = _membership(request, workspace_id)
    raw_day = request.query_params.get("day", "")
    try:
        day = date.fromisoformat(raw_day)
        if day.isoformat() != raw_day:
            raise ValueError("Formato no canónico")
    except (ValueError, TypeError):
        return Response(
            {"day": "Fecha obligatoria en formato ISO YYYY-MM-DD."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    due_candidates = ReminderCandidate.objects.filter(
        scheduled_for=day,
        state=ReminderCandidate.State.PLANNED,
        policy__enabled=True,
    )
    # Exists evita duplicados y mantiene paginación por anotación.
    has_reminder_today = due_candidates.filter(renewal_id=OuterRef("pk"))
    scoped = (
        filtered_renewals(
            request.query_params, _visible_renewals(membership)
        )
        .exclude(status=Renewal.Status.CLOSED)
        .annotate(agenda_has_reminder=Exists(has_reminder_today))
        .filter(Q(expires_on=day) | Q(notice_deadline_on=day) | Q(agenda_has_reminder=True))
        .order_by("expires_on", "id")
    )
    paginator = RenewalPagination()
    page = paginator.paginate_queryset(scoped, request)
    # Prefetch SOLO del día y de políticas activas; sin N+1.
    prefetch_related_objects(
        page,
        Prefetch(
            "reminder_candidates",
            queryset=due_candidates.select_related("policy").order_by(
                "scheduled_for", "id"
            ),
            to_attr="agenda_due_candidates",
        ),
    )
    results = []
    for renewal in page:
        events = []
        if renewal.expires_on == day:
            events.append({"kind": "expiry"})
        if renewal.notice_deadline_on == day:
            # Fecha contractual; no implica que se haya enviado un aviso.
            events.append({"kind": "notice_deadline"})
        for candidate in renewal.agenda_due_candidates:
            events.append({
                "kind": "reminder",
                "candidate_id": candidate.pk,
                "basis": candidate.policy.basis,
            })
        results.append({
            "renewal": RenewalSerializer(renewal).data,
            "events": events,
        })
    response = paginator.get_paginated_response(results)
    response.data["day"] = day.isoformat()
    return response


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def renewals(request, workspace_id):
    membership = _membership(request, workspace_id)
    if request.method == "GET":
        # Los filtros se aplican DENTRO del workspace autorizado, antes de paginar.
        search = request.query_params.get("q", "").strip()
        status_filter = request.query_params.get("status", "").strip()
        if len(search) > 80:
            return Response({"q": "La búsqueda no puede superar 80 caracteres."},
                            status=status.HTTP_400_BAD_REQUEST)
        if status_filter and status_filter not in Renewal.Status.values:
            return Response({"status": "Estado de vencimiento no válido."},
                            status=status.HTTP_400_BAD_REQUEST)
        scoped = filtered_renewals(
            request.query_params, _visible_renewals(membership)
        )
        if search:
            scoped = scoped.filter(customer_reference__icontains=search)
        if status_filter:
            scoped = scoped.filter(status=status_filter)
        scoped = scoped.order_by("expires_on", "id")
        paginator = RenewalPagination()
        page = paginator.paginate_queryset(scoped, request)
        return paginator.get_paginated_response(RenewalSerializer(page, many=True).data)

    serializer = RenewalSerializer(data=request.data, context={"membership": membership})
    serializer.is_valid(raise_exception=True)
    with transaction.atomic():
        # Nunca aceptar workspace desde JSON. Los empleados solo crean trabajo
        # asignado a sí mismos; el propietario puede asignarlo o dejarlo suyo.
        extra = {"workspace": membership.workspace}
        if membership.role != WorkspaceMember.Role.OWNER:
            extra["assigned_to"] = request.user
        elif "assigned_to" not in serializer.validated_data:
            extra["assigned_to"] = request.user
        renewal = serializer.save(**extra)
        make_audit_event(renewal=renewal, actor=request.user)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def renewal_detail(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    if request.method == "GET":
        renewal = get_object_or_404(
            _visible_renewals(membership), pk=renewal_id
        )
        return Response(RenewalSerializer(renewal).data)

    serializer = None
    with transaction.atomic():
        renewal = get_object_or_404(
            _visible_renewals(membership).select_for_update(),
            pk=renewal_id,
        )
        # Snapshot solo en memoria para construir delta no sensible del log.
        before = Renewal(
            customer_reference=renewal.customer_reference,
            full_name=renewal.full_name,
            nickname=renewal.nickname,
            phone=renewal.phone,
            email=renewal.email,
            policy_number=renewal.policy_number,
            entry=renewal.entry,
            modality=renewal.modality,
            insurer=renewal.insurer,
            expires_on=renewal.expires_on,
            notice_deadline_on=renewal.notice_deadline_on,
            status=renewal.status,
            assigned_to_id=renewal.assigned_to_id,
        )
        serializer = RenewalSerializer(
            renewal, data=request.data, partial=True,
            context={"membership": membership},
        )
        serializer.is_valid(raise_exception=True)
        changes = [
            field for field, value in serializer.validated_data.items()
            if getattr(renewal, field) != value
        ]
        if changes:
            serializer.save()
            make_audit_event(renewal=renewal, actor=request.user, before=before)
    return Response(serializer.data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def renewal_history(request, workspace_id, renewal_id):
    """Solo lectura; se autoriza la anotación ANTES de revelar su historial.

    Este registro documenta altas/cambios existentes. No inventa eventos de
    avisos entregados, cierres definitivos o gestiones no implementadas.
    """
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(
        _visible_renewals(membership), pk=renewal_id,
    )
    events = RenewalAuditEvent.objects.filter(
        workspace_id=membership.workspace_id,
        renewal=renewal,
    ).select_related("actor").order_by("-created_at", "-id")
    paginator = RenewalPagination()
    page = paginator.paginate_queryset(events, request)
    results = [{
        "id": str(event.pk),
        "action": event.action,
        "timestamp": event.created_at.isoformat(),
        "actor": event.actor.get_username() if event.actor_id else None,
        "changed_fields": event.changed_fields,
        # Son diferencias técnicas sin referencias/nombres de clientes.
        "metadata": event.metadata,
    } for event in page]
    response = paginator.get_paginated_response(results)
    response["Cache-Control"] = "no-store"
    return response
