"""D1.3: revocación explícita de otras sesiones Django (backend DB).

No revela identificadores de sesión ni permite revocar usuarios ajenos.
El límite evita recorrer sin control tablas de sesiones enormes; a futuro,
un índice de sesiones por usuario sustituirá este mecanismo provisional.
"""
from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.sessions.models import Session
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

MAX_ACTIVE_SESSIONS_SCAN = 5000


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout_other_sessions(request):
    if getattr(settings, "SESSION_ENGINE", "django.contrib.sessions.backends.db") != "django.contrib.sessions.backends.db":
        return Response({"detail": "Motor de sesión no compatible."},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    if set(request.data) != {"password"} or not isinstance(request.data["password"], str):
        return Response({"detail": "Confirmación de contraseña obligatoria."},
                        status=status.HTTP_400_BAD_REQUEST)
    password = request.data["password"]
    if not password or len(password) > 1024:
        return Response({"detail": "Confirmación incorrecta."},
                        status=status.HTTP_400_BAD_REQUEST)
    user = request.user
    if authenticate(request._request, username=user.get_username(), password=password) is None:
        return Response({"detail": "Confirmación incorrecta."},
                        status=status.HTTP_403_FORBIDDEN)
    current_key = request.session.session_key
    if not current_key:
        return Response({"detail": "Sesión actual no disponible."},
                        status=status.HTTP_409_CONFLICT)
    active = Session.objects.filter(expire_date__gt=timezone.now()).order_by("pk")
    # Si hay demasiadas sesiones, no revocar parcialmente ni consumir
    # recursos sin límite: exigir mecanismo indexado antes de escalar.
    if active.values_list("pk", flat=True)[MAX_ACTIVE_SESSIONS_SCAN:MAX_ACTIVE_SESSIONS_SCAN + 1].exists():
        return Response({"detail": "Servicio temporalmente no disponible."},
                        status=status.HTTP_503_SERVICE_UNAVAILABLE)
    to_delete = []
    for session in active.iterator(chunk_size=500):
        if session.session_key == current_key:
            continue
        try:
            session_user_id = session.get_decoded().get("_auth_user_id")
        except Exception:
            continue
        if str(session_user_id) == str(user.pk):
            to_delete.append(session.session_key)
    if to_delete:
        Session.objects.filter(session_key__in=to_delete).delete()
    response = Response({"revoked": len(to_delete)})
    response["Cache-Control"] = "no-store"
    return response
