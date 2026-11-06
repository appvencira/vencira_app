"""Solo endpoints técnicos. No exponer datos de negocios antes de implementar permisos."""
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET
from django.views.decorators.csrf import ensure_csrf_cookie
from django.middleware.csrf import get_token

@require_GET
def health(request):
    response = JsonResponse({"status": "ok"})
    response["Cache-Control"] = "no-store"
    return response

@require_GET
def ready(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception:
        response = JsonResponse({"status": "unavailable"}, status=503)
    else:
        response = JsonResponse({"status": "ready"})
    response["Cache-Control"] = "no-store"
    return response


@require_GET
@ensure_csrf_cookie
def csrf(request):
    """Entregar token CSRF de un único origen sin divulgar sesión/usuarios."""
    response = JsonResponse({"csrfToken": get_token(request)})
    response["Cache-Control"] = "no-store"
    return response
