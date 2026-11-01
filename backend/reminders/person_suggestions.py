"""Sugerencias explícitas y limitadas a anotaciones visibles del usuario.

No existe entidad Persona/CRM ni sincronización entre registros.
"""
from django.db.models import Case, IntegerField, Value, When
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .views import _membership, _visible_renewals


def _prioritized_visible_matches(scoped):
    """Rank only an already authorized queryset; never widen membership."""
    return scoped.annotate(
        _client_first=Case(
            When(entry="clients", then=Value(0)),
            default=Value(1), output_field=IntegerField(),
        )
    ).order_by("_client_first", "full_name", "id")[:5]


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def person_suggestions(request, workspace_id):
    membership = _membership(request, workspace_id)
    allowed = {"name", "phone"}
    if set(request.query_params.keys()) - {"by", "q", "exclude"}:
        return Response({"detail": "Parámetros no permitidos."},
                        status=status.HTTP_400_BAD_REQUEST)
    if any(len(request.query_params.getlist(key)) != 1
           for key in request.query_params.keys()):
        return Response({"detail": "Parámetros duplicados."},
                        status=status.HTTP_400_BAD_REQUEST)
    by = request.query_params.get("by", "name")
    query = request.query_params.get("q", "").strip()
    if by not in allowed or len(query) > 160 or len(query) < 3:
        return Response({"q": "Introduce al menos tres caracteres válidos."},
                        status=status.HTTP_400_BAD_REQUEST)

    scoped = _visible_renewals(membership).exclude(full_name="")
    exclude_id = request.query_params.get("exclude")
    if exclude_id:
        import uuid
        try:
            exclude_id = uuid.UUID(exclude_id)
        except (ValueError, AttributeError):
            return Response({"exclude": "Identificador no válido."},
                            status=status.HTTP_400_BAD_REQUEST)
        scoped = scoped.exclude(pk=exclude_id)

    if by == "name":
        scoped = scoped.filter(full_name__istartswith=query)
    else:
        digits = "".join(char for char in query if char.isdigit())
        if len(digits) < 3 or len(query) > 32:
            return Response({"q": "Teléfono no válido."},
                            status=status.HTTP_400_BAD_REQUEST)
        scoped = scoped.filter(phone__icontains=query).exclude(phone="")

    # Prioritize visible clients before applying the five-result limit.
    matches = _prioritized_visible_matches(scoped)
    response = Response([{
        "source_id": str(item.pk),
        "full_name": item.full_name,
        "nickname": item.nickname,
        "phone": item.phone,
        "email": item.email,
        # Únicamente al elegir explícitamente esta anotación visible:
        # sugerir Clientes si ya está clasificada como tal.
        "suggested_entry": "clients" if item.entry == "clients" else None,
    } for item in matches])
    response["Cache-Control"] = "no-store"
    return response
