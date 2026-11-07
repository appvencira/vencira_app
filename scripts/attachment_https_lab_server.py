"""Private, disposable HTTPS Django WSGI server for attachment transport tests.

The /_att_lab/login/ endpoint exists ONLY in this process; it is not part of
the application's URLs, container image, or operational Django login workflow.
It deliberately avoids exercising production MFA login on a schema stopped at
reminders.0018. Production login remains out of scope.
"""
import os
import ssl
from wsgiref.simple_server import make_server

os.environ["HTTPS"] = "on"
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
from django.core.wsgi import get_wsgi_application

django_app = get_wsgi_application()


def app(environ, start_response):
    # The socket itself is TLS. Tell Django the real request scheme rather
    # than trusting a client-supplied forwarded-proto header.
    environ["wsgi.url_scheme"] = "https"
    environ["HTTP_X_FORWARDED_PROTO"] = "https"
    return django_app(environ, start_response)

from django.contrib.auth import authenticate, login
from django.http import JsonResponse
from django.urls import path
from django.views.decorators.csrf import csrf_protect
from django.views.decorators.http import require_POST
from config.urls import urlpatterns


@require_POST
@csrf_protect
def lab_login(request):
    user = authenticate(
        request,
        username=request.POST.get("username", ""),
        password=request.POST.get("password", ""),
    )
    if user is None or not user.is_active:
        return JsonResponse({"error": "denied"}, status=403)
    login(request, user)
    response = JsonResponse({"lab": "authenticated"})
    response["Cache-Control"] = "no-store"
    return response


# A process-local lab URL only; it never modifies config.urls in Git or image.
urlpatterns.insert(0, path("_att_lab/login/", lab_login))

server = make_server("0.0.0.0", 8443, app)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.minimum_version = ssl.TLSVersion.TLSv1_2
context.load_cert_chain("/tmp/attachment-lab-cert.pem", "/tmp/attachment-lab-key.pem")
server.socket = context.wrap_socket(server.socket, server_side=True)
print("ATT_HTTPS_LAB_SERVER_READY=YES", flush=True)
server.serve_forever()
