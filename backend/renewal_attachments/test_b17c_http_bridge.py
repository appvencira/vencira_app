"""B17C bridge tests on isolated Django/PostgreSQL."""
import json
import threading
import urllib.error
import urllib.request

from contextlib import contextmanager
from http.server import ThreadingHTTPServer

from .test_b17b_http_receiver import B17BHTTPTests
from .offline_http_bridge_b17c import make_handler
from .offline_transport_receiver_b17 import receive_envelope_offline


class B17CBridgeTests(B17BHTTPTests):

    @contextmanager
    def http_receiver(self):
        case = self

        def receive(envelope):
            return receive_envelope_offline(
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

        server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            make_handler(receive),
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

    def test_http_unknown_path(self):
        with self.http_receiver() as port:
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/wrong",
                data=b"{}",
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with self.assertRaises(
                urllib.error.HTTPError
            ) as raised:
                urllib.request.urlopen(request, timeout=5)

        self.assertEqual(raised.exception.code, 404)
        self.assertEqual(self.replay_count(), 0)

    def test_http_malformed_json(self):
        with self.http_receiver() as port:
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/evidence",
                data=b"{invalid",
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with self.assertRaises(
                urllib.error.HTTPError
            ) as raised:
                urllib.request.urlopen(request, timeout=5)

        self.assertEqual(raised.exception.code, 403)
        self.assertEqual(self.replay_count(), 0)

    def test_http_rejects_oversized_payload(self):
        with self.http_receiver() as port:
            request = urllib.request.Request(
                f"http://127.0.0.1:{port}/evidence",
                data=b"x" * 8193,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with self.assertRaises(
                urllib.error.HTTPError
            ) as raised:
                urllib.request.urlopen(request, timeout=5)

        self.assertEqual(raised.exception.code, 413)
        self.assertEqual(self.replay_count(), 0)
