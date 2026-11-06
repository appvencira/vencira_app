#!/usr/bin/env python3
"""Loopback-only I4 HTTPS static + Django reverse proxy. CI harness, not production."""
import argparse
import http.client
import mimetypes
import ssl
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROUTES = ("/api/", "/accounts/", "/admin/")
SKIP_HEADERS = {"connection", "transfer-encoding", "keep-alive",
                "proxy-authenticate", "proxy-authorization", "te", "trailer", "upgrade"}


class Handler(BaseHTTPRequestHandler):
    root = None

    def do_GET(self):
        self.dispatch()

    def do_HEAD(self):
        self.dispatch()

    def do_POST(self):
        self.dispatch()

    def do_PATCH(self):
        self.dispatch()

    def do_DELETE(self):
        self.dispatch()

    def dispatch(self):
        path = urlsplit(self.path).path
        if path.startswith(ROUTES):
            return self.proxy()
        if self.command not in ("GET", "HEAD"):
            return self.send_error(405)
        return self.static(path)

    def proxy(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length > 1024 * 1024:
            return self.send_error(413)
        body = self.rfile.read(length) if length else None
        headers = {k: v for k, v in self.headers.items()
                   if k.lower() not in SKIP_HEADERS}
        # Django trusts only this loopback proxy to declare TLS.
        headers["X-Forwarded-Proto"] = "https"
        conn = http.client.HTTPConnection("127.0.0.1", 18731, timeout=10)
        try:
            conn.request(self.command, self.path, body=body, headers=headers)
            response = conn.getresponse()
            payload = response.read()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in SKIP_HEADERS and key.lower() != "content-length":
                    self.send_header(key, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(payload)
        except (OSError, http.client.HTTPException):
            self.send_error(502, "I4 loopback Django unavailable")
        finally:
            conn.close()

    def static(self, path):
        name = unquote(path).lstrip("/") or "index.html"
        if name.endswith("/") or ".." in Path(name).parts or "\\" in name:
            return self.send_error(404)
        root = self.root.resolve()
        target = (root / name).resolve()
        if not target.is_relative_to(root) or not target.is_file():
            return self.send_error(404)
        contents = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(name)[0] or "application/octet-stream")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(contents)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(contents)

    def log_message(self, fmt, *args):
        # Do not print cookies, credentials or form bodies.
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--web", type=Path, required=True)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()
    if not (args.web / "index.html").is_file():
        raise SystemExit("I4_WEB_BUILD_REQUIRED")
    Handler.root = args.web
    server = ThreadingHTTPServer(("127.0.0.1", 18732), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(args.cert, args.key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print("I4_HTTPS_LOOPBACK_READY=YES", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
