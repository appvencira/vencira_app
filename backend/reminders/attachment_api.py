"""C-FICHA API: metadata listing only; upload, download and delete closed.

These endpoints are intentionally NOT a release of storage or malware scanning.
"""
from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .attachment_gate import accessible_attachment_queryset
from .views import _membership, _visible_renewals


@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def renewal_attachments(request, workspace_id, renewal_id):
    member = _membership(request, workspace_id)
    get_object_or_404(_visible_renewals(member), pk=renewal_id)
    if request.method != "GET":
        response = Response({"detail": "Adjuntos no habilitados."},
                            status=status.HTTP_403_FORBIDDEN)
        response["Cache-Control"] = "no-store"
        return response
    records = accessible_attachment_queryset(member).filter(
        renewal_id=renewal_id).order_by("-created_at", "-id")[:50]
    response = Response({"results": [{
        "id": str(item.pk), "display_name": item.display_name,
        "content_type": item.content_type, "byte_size": item.byte_size,
        "state": item.state, "created_at": item.created_at.isoformat(),
        "download_enabled": False, "delete_enabled": False,
    } for item in records],
        "capabilities": {
            "upload": False, "download": False, "delete": False,
            "reason": "SECURITY_REVIEW_PENDING",
        },
        "upload_enabled": False})
    response["Cache-Control"] = "no-store"
    return response


@api_view(["GET", "DELETE"])
@permission_classes([IsAuthenticated])
def renewal_attachment_detail(request, workspace_id, renewal_id, attachment_id):
    member = _membership(request, workspace_id)
    get_object_or_404(_visible_renewals(member), pk=renewal_id)
    get_object_or_404(accessible_attachment_queryset(member),
                      pk=attachment_id, renewal_id=renewal_id)
    response = Response({"detail": "Descarga y eliminación no habilitadas."},
                        status=status.HTTP_403_FORBIDDEN)
    response["Cache-Control"] = "no-store"
    return response
