"""Solo endpoints técnicos. No exponer datos de negocios antes de implementar permisos."""
from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET

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
