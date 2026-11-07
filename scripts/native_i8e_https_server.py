"""I8-E isolated TLS bridge for I8-D only; refuses operational configuration."""
import os
import ssl
from wsgiref.simple_server import make_server

if not (
    os.getenv("VENCIRA_ENV") == "test"
    and os.getenv("VENCIRA_NATIVE_SERVICE_CANDIDATE") == "1"
    and os.getenv("VENCIRA_I8D_HTTP_LAB") == "1"
    and os.getenv("VENCIRA_I8E_NETWORK_ISOLATED") == "1"
    and os.getenv("VENCIRA_DB_ENGINE") == "postgresql"
    and os.getenv("POSTGRES_DB") == "i8elab"
):
    raise SystemExit("NATIVE_I8E_SERVER_GUARD=DENIED")

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
import django
from django.conf import settings
from django.urls import clear_url_caches
from django.core.wsgi import get_wsgi_application

django.setup()
if (settings.VENCIRA_ENV != "test"
        or not settings.VENCIRA_NATIVE_SERVICE_CANDIDATE
        or settings.VENCIRA_NATIVE_BEARER_ENABLED
        or "native_mobile_service" not in settings.INSTALLED_APPS):
    raise SystemExit("NATIVE_I8E_SETTINGS_GUARD=DENIED")
settings.ROOT_URLCONF = "native_mobile_service.test_i8d_urls"
clear_url_caches()
django_application = get_wsgi_application()


def app(environ, start_response):
    environ["wsgi.url_scheme"] = "https"
    environ["HTTP_X_FORWARDED_PROTO"] = "https"
    return django_application(environ, start_response)


server = make_server("0.0.0.0", 8443, app)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain("/tmp/i8e-cert.pem", "/tmp/i8e-key.pem")
server.socket = ctx.wrap_socket(server.socket, server_side=True)
print("NATIVE_I8E_HTTPS_SERVER_READY=OK", flush=True)
server.serve_forever()
