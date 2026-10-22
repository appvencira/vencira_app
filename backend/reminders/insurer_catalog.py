"""Aseguradoras locales de cada cuenta. SIN atribuirles registro DGSFP verificado."""
import unicodedata
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import WorkspaceInsurer, WorkspaceMember


def _membership(request, workspace_id):
    return get_object_or_404(
        WorkspaceMember.objects.select_related("workspace"),
        workspace_id=workspace_id, user=request.user,
    )


def _owner(request, workspace_id):
    membership = _membership(request, workspace_id)
    return membership if membership.role == WorkspaceMember.Role.OWNER else None


def _clean_name(value):
    if not isinstance(value, str):
        return None
    value = unicodedata.normalize("NFC", value.strip())
    if not 2 <= len(value) <= 140 or any(unicodedata.category(c)[0] == "C" for c in value):
        return None
    return value


def _result(row):
    return {"id": str(row.pk), "name": row.name, "active": row.active}


def _error(detail, status_code=400):
    return Response({"detail": detail}, status=status_code)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def insurers(request, workspace_id):
    member = _membership(request, workspace_id)
    if request.method == "GET":
        if set(request.query_params) - {"q"} or len(request.query_params.getlist("q")) > 1:
            return _error("Parámetros de búsqueda no válidos.")
        query = request.query_params.get("q", "").strip()
        if len(query) > 80:
            return _error("La búsqueda supera 80 caracteres.")
        queryset = WorkspaceInsurer.objects.filter(workspace_id=member.workspace_id)
        if query:
            queryset = queryset.filter(name__icontains=query)
        response = Response([_result(row) for row in queryset[:100]])
        response["Cache-Control"] = "no-store"
        return response

    if member.role != WorkspaceMember.Role.OWNER:
        return _error("Solo el propietario puede añadir aseguradoras.", 403)
    if set(request.data) != {"name"}:
        return _error("Solo se permite name.")
    name = _clean_name(request.data.get("name"))
    if name is None:
        return _error("Nombre inválido (2–140 caracteres).")
    try:
        with transaction.atomic():
            row = WorkspaceInsurer.objects.create(
                workspace=member.workspace, name=name, normalized_name=name.casefold(),
            )
    except IntegrityError:
        return _error("Ya existe esa aseguradora en la cuenta.", 409)
    return Response(_result(row), status=status.HTTP_201_CREATED)


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def insurer_detail(request, workspace_id, insurer_id):
    member = _owner(request, workspace_id)
    if member is None:
        return _error("Solo el propietario puede modificar aseguradoras.", 403)
    with transaction.atomic():
        row = get_object_or_404(
            WorkspaceInsurer.objects.select_for_update(),
            pk=insurer_id, workspace_id=member.workspace_id,
        )
        if request.method == "DELETE":
            if not row.active:
                return _error("Aseguradora ya desactivada.", 409)
            row.active = False
            row.save(update_fields=["active"])
            return Response(status=status.HTTP_204_NO_CONTENT)

        allowed = {"name", "active"}
        if not request.data or set(request.data) - allowed:
            return _error("Solo se permiten name y active.")
        if "active" in request.data and request.data["active"] is not True:
            return _error("Para desactivar usa DELETE; active solo admite true.")
        if "name" in request.data:
            name = _clean_name(request.data.get("name"))
            if name is None:
                return _error("Nombre inválido.")
            row.name = name
            row.normalized_name = name.casefold()
        if "active" in request.data:
            row.active = True
        try:
            row.save(update_fields=["name", "normalized_name", "active"])
        except IntegrityError:
            return _error("Ya existe esa aseguradora en la cuenta.", 409)
    return Response(_result(row))
