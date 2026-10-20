"""Endpoints autorizados por membresía. Las rutas nunca reciben un tenant del cuerpo JSON."""
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Renewal, WorkspaceMember
from .pagination import RenewalPagination
from .serializers import MembershipSerializer, RenewalSerializer


def _membership(request, workspace_id):
    # No revelar si el workspace existe para un usuario que no pertenece a él.
    return get_object_or_404(
        WorkspaceMember.objects.select_related("workspace"),
        workspace_id=workspace_id,
        user=request.user,
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    return Response({"id": request.user.pk, "username": request.user.get_username()})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def workspaces(request):
    memberships = WorkspaceMember.objects.filter(user=request.user).select_related("workspace").order_by("workspace__name", "workspace_id")
    return Response(MembershipSerializer(memberships, many=True).data)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def renewals(request, workspace_id):
    membership = _membership(request, workspace_id)
    if request.method == "GET":
        scoped = Renewal.objects.filter(workspace_id=membership.workspace_id).order_by("expires_on", "id")
        paginator = RenewalPagination()
        page = paginator.paginate_queryset(scoped, request)
        return paginator.get_paginated_response(RenewalSerializer(page, many=True).data)

    serializer = RenewalSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    # workspace jamás se acepta desde la solicitud del cliente.
    serializer.save(workspace=membership.workspace)
    return Response(serializer.data, status=status.HTTP_201_CREATED)


@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def renewal_detail(request, workspace_id, renewal_id):
    membership = _membership(request, workspace_id)
    renewal = get_object_or_404(Renewal, pk=renewal_id, workspace_id=membership.workspace_id)
    if request.method == "GET":
        return Response(RenewalSerializer(renewal).data)
    serializer = RenewalSerializer(renewal, data=request.data, partial=True)
    serializer.is_valid(raise_exception=True)
    serializer.save()
    return Response(serializer.data)
