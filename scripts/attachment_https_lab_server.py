"""Disposable lab HTTPS WSGI server, never used by the operational application."""
import os
import ssl
from wsgiref.simple_server import make_server

os.environ["HTTPS"] = "on"
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
from django.core.wsgi import get_wsgi_application

app = get_wsgi_application()
server = make_server("0.0.0.0", 8443, app)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.minimum_version = ssl.TLSVersion.TLSv1_2
context.load_cert_chain("/tmp/attachment-lab-cert.pem", "/tmp/attachment-lab-key.pem")
server.socket = context.wrap_socket(server.socket, server_side=True)
print("ATT_HTTPS_LAB_SERVER_READY=YES", flush=True)
server.serve_forever()
