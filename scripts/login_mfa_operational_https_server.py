"""Real operational Django login and MFA over HTTPS in a disposable lab.

No synthetic login route; only production URLconf, served through ephemeral TLS.
"""
import os
import ssl
from wsgiref.simple_server import make_server

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
from django.core.wsgi import get_wsgi_application

django_app = get_wsgi_application()


def app(environ, start_response):
    environ["wsgi.url_scheme"] = "https"
    environ["HTTP_X_FORWARDED_PROTO"] = "https"
    return django_app(environ, start_response)


server = make_server("0.0.0.0", 8443, app)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.minimum_version = ssl.TLSVersion.TLSv1_2
context.load_cert_chain("/tmp/login-mfa-cert.pem", "/tmp/login-mfa-key.pem")
server.socket = context.wrap_socket(server.socket, server_side=True)
print("LOGIN_MFA_HTTPS_SERVER_READY=YES", flush=True)
server.serve_forever()
