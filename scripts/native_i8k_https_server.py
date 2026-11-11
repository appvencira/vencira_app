"""I8-K isolated TLS bridge for recovery-only URLconf; refuses operational configuration."""
import os
import ssl
from wsgiref.simple_server import make_server

if not (
    os.getenv("VENCIRA_ENV") == "test"
    and os.getenv("VENCIRA_NATIVE_SERVICE_CANDIDATE") == "1"
    and os.getenv("VENCIRA_I8K_RECOVERY_LAB") == "1"
    and os.getenv("VENCIRA_I8K_NETWORK_ISOLATED") == "1"
    and os.getenv("VENCIRA_DB_ENGINE") == "postgresql"
    and os.getenv("POSTGRES_DB") == "i8klab"
):
    raise SystemExit("NATIVE_I8K_SERVER_GUARD=DENIED")

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
    raise SystemExit("NATIVE_I8K_SETTINGS_GUARD=DENIED")
if os.getenv("VENCIRA_D25_WORKSPACE_TLS_LAB") == "1":
    if not (os.getenv("VENCIRA_D22_HTTP_LAB") == "1"
            and os.getenv("VENCIRA_I8M_FLUTTER_INTERNAL_ONLY") == "1"):
        raise SystemExit("D25_WORKSPACE_LAB_GUARD=DENIED")
    settings.ROOT_URLCONF = "native_mobile_service.test_d22_urls"
else:
    settings.ROOT_URLCONF = "native_mobile_service.test_i8k_recovery_urls"
clear_url_caches()
django_application = get_wsgi_application()


def app(environ, start_response):
    environ["wsgi.url_scheme"] = "https"
    environ["HTTP_X_FORWARDED_PROTO"] = "https"
    return django_application(environ, start_response)


# Standard HTTPS port is enabled exclusively for the I8-M internal Flutter
# lab. The legacy Python boundary continues to listen on 8443.
port = 443 if os.getenv("VENCIRA_I8M_FLUTTER_INTERNAL_ONLY") == "1" else 8443
server = make_server("0.0.0.0", port, app)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.minimum_version = ssl.TLSVersion.TLSv1_2
ctx.load_cert_chain("/tmp/i8k-cert.pem", "/tmp/i8k-key.pem")
server.socket = ctx.wrap_socket(server.socket, server_side=True)
print("NATIVE_I8K_HTTPS_SERVER_READY=OK", flush=True)
server.serve_forever()
