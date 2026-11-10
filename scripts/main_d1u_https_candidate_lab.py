"""D1-U isolated candidate HTTPS server and strict CA/hostname client test.

HTTPS terminates in this *laboratory WSGI server*, NOT operational Caddy.
Run only on a disposable Docker network with a synthetic PostgreSQL database.
"""
import argparse
import ssl
import sys
import urllib.error
import urllib.request
from wsgiref.simple_server import WSGIRequestHandler, WSGIServer, make_server


class SecureWSGIHandler(WSGIRequestHandler):
    def get_environ(self):
        env = super().get_environ()
        env["wsgi.url_scheme"] = "https"
        return env

    def log_message(self, format, *args):
        # No cookies, headers, usernames or request paths in stdout.
        pass


def serve(cert, key):
    from django.core.wsgi import get_wsgi_application
    server = make_server("127.0.0.1", 18443, get_wsgi_application(),
                         server_class=WSGIServer, handler_class=SecureWSGIHandler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(certfile=cert, keyfile=key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print("D1U_LAB_HTTPS_LISTENING=YES", flush=True)
    server.serve_forever()


def get_code(url, context):
    request = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(request, context=context, timeout=5) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def probe(cert):
    valid = ssl.create_default_context(cafile=cert)
    cases = (
        ("/api/health/", (200,)),
        ("/api/ready/", (200,)),
        ("/accounts/login/", (200,)),
        ("/api/v1/csrf/", (200,)),
        ("/api/v1/me/", (401, 403)),
        ("/api/v1/native/issue/", (404,)),
        ("/api/v1/native/refresh/", (404,)),
    )
    for path, expected in cases:
        if get_code("https://localhost:18443" + path, valid) not in expected:
            raise RuntimeError("expected HTTPS status not returned")
    print("D1U_CANDIDATE_TLS_VERIFIED=PASS")
    print("D1U_CANDIDATE_HTTPS_HTTP_CONTRACT=PASS")
    try:
        get_code("https://127.0.0.1:18443/api/health/", valid)
    except (ssl.SSLCertVerificationError, urllib.error.URLError) as exc:
        if isinstance(exc, urllib.error.URLError) and not isinstance(exc.reason, ssl.SSLCertVerificationError):
            raise
        print("D1U_HOSTNAME_MISMATCH_DENIED=PASS")
    else:
        raise RuntimeError("hostname mismatch unexpectedly accepted")
    try:
        get_code("https://localhost:18443/api/health/", ssl.create_default_context())
    except (ssl.SSLCertVerificationError, urllib.error.URLError) as exc:
        if isinstance(exc, urllib.error.URLError) and not isinstance(exc.reason, ssl.SSLCertVerificationError):
            raise
        print("D1U_UNTRUSTED_CA_DENIED=PASS")
    else:
        raise RuntimeError("untrusted certificate unexpectedly accepted")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("serve", "probe"))
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key")
    args = parser.parse_args()
    if args.mode == "serve":
        if not args.key:
            raise ValueError("private key required for server")
        serve(args.cert, args.key)
    else:
        probe(args.cert)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("D1U_HTTPS_LAB_FAILURE=YES", file=sys.stderr)
        raise SystemExit(1)
