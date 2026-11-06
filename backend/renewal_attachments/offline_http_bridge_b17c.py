"""HTTP adapter for B17 rehearsals. Not a public API."""
import json
from http.server import BaseHTTPRequestHandler

from django.core.exceptions import PermissionDenied
from django.db import IntegrityError


def make_handler(receive):
    """Delegate verified envelope persistence to B17.

    The injected receive function must use the B17 atomic
    receiver. This adapter has no signing or DB logic.
    """

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def respond(self, status):
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_POST(self):
            if self.path != "/evidence":
                return self.respond(404)

            try:
                if self.headers.get("Content-Type") != "application/json":
                    return self.respond(415)

                raw_length = self.headers.get("Content-Length", "")
                if not raw_length.isascii() or not raw_length.isdecimal():
                    return self.respond(413)

                length = int(raw_length)
                if not 0 < length <= 8192:
                    return self.respond(413)

                envelope = json.loads(self.rfile.read(length))

                receive(envelope)

            except IntegrityError:
                return self.respond(409)
            except (
                PermissionDenied, ValueError, TypeError,
                UnicodeError, json.JSONDecodeError,
            ):
                return self.respond(403)
            except Exception:
                # Fail closed; no exception detail exposed.
                return self.respond(503)

            return self.respond(201)

    return Handler
