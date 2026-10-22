"""Catálogo por cuenta. Base visible sin copiarla a cada nueva organización."""
import re
import uuid
from django.db import transaction
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import WorkspaceMember, WorkspaceModality
from .views import _membership

# Identificadores estables. No traducir estos códigos en base de datos.
DEFAULT_MODALITIES = (
    ("autos", "Autos"),
    ("motos", "Motos"),
    ("patinetes", "Patinetes"),
    ("hogar", "Hogar"),
    ("comercio", "Comercio"),
    ("decesos", "Decesos"),
    ("salud", "Salud"),
    ("vida", "Vida"),
    ("accidentes", "Accidentes"),
    ("rc", "Responsabilidad civil"),
    ("comunidades", "Comunidades"),
    ("otros", "Otros"),
)
DEFAULT_LABELS = dict(DEFAULT_MODALITIES)
CODE_RE = re.compile(r"^[a-z][a-z0-9_-]{0,63}$")


def catalog_for(workspace_id):
    overrides = {
        row.code: row for row in WorkspaceModality.objects.filter(
            workspace_id=workspace_id
        )
    }
    rows = []
    for code, label in DEFAULT_MODALITIES:
        override = overrides.pop(code, None)
        rows.append({
            "code": code,
            "label": override.label if override else label,
            "active": override.active if override else True,
            "builtin": True,
        })
    for item in sorted(overrides.values(), key=lambda x: (x.label.casefold(), x.code)):
        rows.append({
            "code": item.code, "label": item.label,
            "active": item.active, "builtin": False,
        })
    return rows


def modality_valid(workspace_id, code):
    if code == "":
        return True
    for row in catalog_for(workspace_id):
        if row["code"] == code:
            return row["active"]
    return False


def _validate_label(value):
    if not isinstance(value, str):
        return None
    clean = value.strip()
    if not 1 <= len(clean) <= 80 or any(ord(ch) < 32 for ch in clean):
        return None
    return clean


def _duplicate_label(workspace_id, label, except_code=None):
    return any(
        row["active"] and row["code"] != except_code and
        row["label"].casefold() == label.casefold()
        for row in catalog_for(workspace_id)
    )


def _owner(request, workspace_id):
    member = _membership(request, workspace_id)
    if member.role != WorkspaceMember.Role.OWNER:
        return None
    return member


def _error(message, code=status.HTTP_400_BAD_REQUEST):
    return Response({"detail": message}, status=code)


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def modalities(request, workspace_id):
    member = _membership(request, workspace_id)
    if request.method == "GET":
        result = Response(catalog_for(member.workspace_id))
        result["Cache-Control"] = "no-store"
        return result

    if member.role != WorkspaceMember.Role.OWNER:
        return _error("Solo el propietario puede modificar modalidades.", 403)
    if set(request.data) != {"label"}:
        return _error("Solo se permite el campo label.")
    label = _validate_label(request.data.get("label"))
    if label is None:
        return _error("Nombre de modalidad inválido (1–80 caracteres).")
    with transaction.atomic():
        if _duplicate_label(member.workspace_id, label):
            return _error("Ya existe una modalidad activa con ese nombre.", 409)
        row = WorkspaceModality.objects.create(
            workspace=member.workspace, code="custom-" + uuid.uuid4().hex,
            label=label,
        )
    return Response({
        "code": row.code, "label": row.label,
        "active": True, "builtin": False,
    }, status=status.HTTP_201_CREATED)


@api_view(["PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def modality_detail(request, workspace_id, code):
    member = _owner(request, workspace_id)
    if member is None:
        return _error("Solo el propietario puede modificar modalidades.", 403)
    if not CODE_RE.fullmatch(code):
        return _error("Código de modalidad inválido.", 404)
    builtin = code in DEFAULT_LABELS
    if not builtin and not code.startswith("custom-"):
        return _error("Modalidad inexistente.", 404)
    if not builtin and not WorkspaceModality.objects.filter(
        workspace_id=member.workspace_id, code=code
    ).exists():
        return _error("Modalidad inexistente.", 404)

    with transaction.atomic():
        existing = WorkspaceModality.objects.select_for_update().filter(
            workspace_id=member.workspace_id, code=code
        ).first()
        if request.method == "DELETE":
            if existing is None:
                existing = WorkspaceModality.objects.create(
                    workspace=member.workspace, code=code,
                    label=DEFAULT_LABELS[code], active=False,
                )
            elif not existing.active:
                return _error("La modalidad ya está desactivada.", 409)
            else:
                existing.active = False
                existing.save(update_fields=["active"])
            return Response(status=204)

        # PATCH con label renombra; PATCH con active=true reactiva.
        if set(request.data) not in ({"label"}, {"active"}, {"label", "active"}):
            return _error("Solo se permiten label y active.")
        if "active" in request.data and request.data["active"] is not True:
            return _error("Para eliminar usa DELETE; active solo admite true.")
        label = (
            _validate_label(request.data["label"])
            if "label" in request.data else
            (existing.label if existing else DEFAULT_LABELS[code])
        )
        if label is None:
            return _error("Nombre de modalidad inválido (1–80 caracteres).")
        if _duplicate_label(member.workspace_id, label, except_code=code):
            return _error("Ya existe una modalidad activa con ese nombre.", 409)
        if existing is None:
            existing = WorkspaceModality.objects.create(
                workspace=member.workspace, code=code, label=label
            )
        else:
            existing.label = label
            if "active" in request.data:
                existing.active = True
            existing.save(update_fields=["label", "active"])
        return Response({
            "code": code, "label": existing.label,
            "active": existing.active, "builtin": builtin,
        })
