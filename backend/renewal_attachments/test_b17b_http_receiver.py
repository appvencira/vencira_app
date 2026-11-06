"""B17B: HTTP local a receptor B17A, exclusivamente en ensayos."""
import json
import threading
import urllib.error
import urllib.request

from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from django.core.exceptions import PermissionDenied
from django.db import IntegrityError

from .test_b17_transport_receiver import B17TransportReceiverTests


class B17BHTTPTests(B17TransportReceiverTests):

    @contextmanager
    def http_receiver(self):
        case = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                if self.path != "/evidence":
                    self.send_response(404)
                    self.end_headers()
                    return

                try:
                    length = int(
                        self.headers.get("Content-Length", "-1")
                    )
                    if not 0 < length <= 8192:
                        raise PermissionDenied("INVALID_SIZE")

                    envelope = json.loads(
                        self.rfile.read(length)
                    )

                    from .offline_transport_receiver_b17 import (
                        receive_envelope_offline,
                    )

                    receive_envelope_offline(
                        envelope=envelope,
                        transport_key=case.transport_key,
                        registry=case.registry,
                        attachment_id=case.item.pk,
                        expected_fingerprint=case.fingerprint,
                        now=case.now,
                        fail_after_evidence=getattr(
                            case, "force_rollback", False
                        ),
                    )

                    status = 201
                except IntegrityError:
                    status = 409
                except (
                    PermissionDenied, ValueError,
                    TypeError, UnicodeError,
                ):
                    status = 403
                except RuntimeError:
                    status = 503

                self.send_response(status)
                self.send_header("Content-Length", "0")
                self.end_headers()

        server = ThreadingHTTPServer(
            ("127.0.0.1", 0), Handler
        )
        thread = threading.Thread(
            target=server.serve_forever,
            daemon=True,
        )
        thread.start()

        try:
            yield server.server_address[1]
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)

    def post(self, port, envelope):
        url = f"http://127.0.0.1:{port}/evidence"
        data = json.dumps(
            envelope, sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")

        request = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(
                request, timeout=5
            ) as response:
                return response.status
        except urllib.error.HTTPError as exc:
            return exc.code

    def envelope(self, body=None, mac=None):
        return {
            "body": self.body if body is None else body,
            "mac": self.mac if mac is None else mac,
        }

    def test_http_accept_and_replay(self):
        with self.http_receiver() as port:
            self.assertEqual(
                self.post(port, self.envelope()), 201
            )
            self.assertEqual(
                self.post(port, self.envelope()), 409
            )

        self.assertEqual(self.replay_count(), 1)
        self.assertEqual(
            self.item.scan_evidence.count(), 1
        )

    def test_http_bad_mac_rejected_no_write(self):
        with self.http_receiver() as port:
            status = self.post(
                port, self.envelope(mac="0" * 64)
            )

        self.assertEqual(status, 403)
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(
            self.item.scan_evidence.count(), 0
        )

    def test_http_tampered_evidence_rejected(self):
        altered = json.loads(json.dumps(self.body))
        altered["evidence"]["verdict"] = "infected"

        with self.http_receiver() as port:
            status = self.post(
                port,
                self.envelope(
                    body=altered,
                    mac=self.sign_transport(altered),
                ),
            )

        self.assertEqual(status, 403)
        self.assertEqual(self.replay_count(), 0)
        self.assertEqual(
            self.item.scan_evidence.count(), 0
        )

    def test_http_rollback_does_not_consume_nonce(self):
        self.force_rollback = True

        with self.http_receiver() as port:
            self.assertEqual(
                self.post(port, self.envelope()), 503
            )
            self.assertEqual(self.replay_count(), 0)
            self.assertEqual(
                self.item.scan_evidence.count(), 0
            )

            self.force_rollback = False
            self.assertEqual(
                self.post(port, self.envelope()), 201
            )

        self.assertEqual(self.replay_count(), 1)
        self.assertEqual(
            self.item.scan_evidence.count(), 1
        )
