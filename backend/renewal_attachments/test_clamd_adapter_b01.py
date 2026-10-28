"""B01: pruebas sintéticas de protocolo ClamAV.

No requieren servicio antivirus ni datos reales.
"""
import os
import socket
import struct
import tempfile
import threading
from pathlib import Path

from django.test import SimpleTestCase

from .clamd_adapter import (
    MalwareDetected,
    MalwareScanUnavailable,
    scan_with_clamd,
)


class B01ClamdAdapterTests(SimpleTestCase):

    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.path = str(Path(tmp.name) / "clamd.sock")

    def mock_engine(self, reply):
        ready = threading.Event()
        done = threading.Event()
        errors = []

        def serve():
            try:
                with socket.socket(
                    socket.AF_UNIX, socket.SOCK_STREAM
                ) as server:
                    server.bind(self.path)
                    server.listen(1)
                    server.settimeout(5)
                    ready.set()
                    conn, _ = server.accept()
                    with conn:
                        conn.settimeout(5)
                        header = conn.recv(10)
                        assert header == b"zINSTREAM\x00"

                        while True:
                            count = b""
                            while len(count) < 4:
                                part = conn.recv(4 - len(count))
                                if not part:
                                    raise AssertionError(
                                        "Truncated chunk length"
                                    )
                                count += part
                            size = struct.unpack("!I", count)[0]
                            if not size:
                                break
                            while size:
                                part = conn.recv(min(size, 65536))
                                if not part:
                                    raise AssertionError(
                                        "Truncated chunk"
                                    )
                                size -= len(part)
                        if reply is not None:
                            conn.sendall(reply)
            except Exception as exc:
                errors.append(exc)
                ready.set()
            finally:
                done.set()

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        self.assertTrue(ready.wait(5))
        self.addCleanup(lambda: thread.join(timeout=6))
        self.addCleanup(
            lambda: self.assertFalse(errors, str(errors))
        )
        return done

    def test_clean(self):
        self.mock_engine(b"stream: OK\x00")
        self.assertIsNone(
            scan_with_clamd(
                b"synthetic-clean", socket_path=self.path
            )
        )

    def test_malware(self):
        self.mock_engine(
            b"stream: Test.Signature FOUND\x00"
        )
        with self.assertRaises(MalwareDetected):
            scan_with_clamd(
                b"synthetic-bad", socket_path=self.path
            )

    def test_engine_error_closed(self):
        self.mock_engine(
            b"stream: INSTREAM size limit exceeded. ERROR\x00"
        )
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"synthetic", socket_path=self.path
            )

    def test_disconnect_closed(self):
        self.mock_engine(None)
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"synthetic", socket_path=self.path
            )

    def test_missing_socket_closed(self):
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"synthetic", socket_path=self.path
            )

    def test_oversized_input_closed(self):
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"x" * (10 * 1024 * 1024 + 1),
                socket_path=self.path,
            )

    def test_empty_input_closed(self):
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"", socket_path=self.path
            )

    def test_invalid_socket_path_closed(self):
        with self.assertRaises(MalwareScanUnavailable):
            scan_with_clamd(
                b"synthetic", socket_path="relative.sock"
            )
