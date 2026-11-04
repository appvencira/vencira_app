#!/usr/bin/env python3
"""G13 relay safety smoke: only loopback, active listener not stolen, raw bytes."""
import importlib.util
from pathlib import Path
import socket
import threading
import unittest

SOURCE = Path(__file__).with_name("g13_usb_loopback_relay.py")
SPEC = importlib.util.spec_from_file_location("g13_relay_test_only", SOURCE)
assert SPEC is not None and SPEC.loader is not None
relay = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(relay)


class RelaySafetySmoke(unittest.TestCase):
    def test_only_private_docker_peer(self):
        self.assertEqual(relay._private_docker_peer("172.25.0.4"), "172.25.0.4")
        for invalid in ("127.0.0.1", "8.8.8.8", "169.254.1.1", "::1"):
            with self.subTest(peer=invalid):
                with self.assertRaises(SystemExit):
                    relay._private_docker_peer(invalid)

    def test_bind_is_localhost_and_does_not_steal_active_listener(self):
        with relay.LoopbackServer(("127.0.0.1", 0), relay.Forward) as first:
            port = first.server_address[1]
            self.assertEqual(first.server_address[0], "127.0.0.1")
            self.assertTrue(relay.LoopbackServer.allow_reuse_address)
            with self.assertRaises(OSError):
                with relay.LoopbackServer(("127.0.0.1", port), relay.Forward):
                    pass

    def test_raw_stream_forwarding_on_ephemeral_loopback_ports(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as upstream:
            upstream.bind(("127.0.0.1", 0))
            upstream.listen(1)
            upstream.settimeout(5)
            original_port = relay.SERVER_PORT
            relay.SERVER_PORT = upstream.getsockname()[1]
            response = []
            errors = []

            def echo_once():
                try:
                    with upstream.accept()[0] as peer:
                        peer.settimeout(5)
                        payload = peer.recv(1024)
                        response.append(payload)
                        peer.sendall(payload)
                except OSError as exc:
                    errors.append(type(exc).__name__)

            echo = threading.Thread(target=echo_once, daemon=True)
            echo.start()
            try:
                with relay.LoopbackServer(("127.0.0.1", 0), relay.Forward) as gateway:
                    gateway.private_peer = "127.0.0.1"  # only test-local stub
                    runner = threading.Thread(
                        target=gateway.serve_forever, kwargs={"poll_interval": 0.01},
                        daemon=True,
                    )
                    runner.start()
                    try:
                        with socket.create_connection(
                            ("127.0.0.1", gateway.server_address[1]), timeout=5
                        ) as client:
                            client.settimeout(5)
                            client.sendall(b"G13_DISPOSABLE_TEST_BYTES")
                            self.assertEqual(
                                client.recv(1024), b"G13_DISPOSABLE_TEST_BYTES"
                            )
                    finally:
                        gateway.shutdown()
                        runner.join(timeout=5)
            finally:
                relay.SERVER_PORT = original_port
                echo.join(timeout=5)
            self.assertFalse(errors)
            self.assertEqual(response, [b"G13_DISPOSABLE_TEST_BYTES"])


if __name__ == "__main__":
    unittest.main()
