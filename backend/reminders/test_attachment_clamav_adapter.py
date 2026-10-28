"""No antivirus process, socket, external network, or real document."""
from unittest.mock import patch
import stat
from types import SimpleNamespace
from django.test import SimpleTestCase
from .attachment_clamav_adapter import scan_with_clamd


class FakeSocket:
    def __init__(self, response=None, failure=False):
        self.response = response
        self.failure = failure
        self.sent = bytearray()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def settimeout(self, value):
        pass

    def connect(self, path):
        if self.failure:
            raise OSError("offline")

    def sendall(self, payload):
        self.sent.extend(payload)

    def recv(self, size):
        if self.response is None:
            return b""
        answer, self.response = self.response, None
        return answer


class ClamavAdapterTests(SimpleTestCase):
    def scan(self, response, payload=b"synthetic", failure=False):
        fake = FakeSocket(response, failure)
        with patch("reminders.attachment_clamav_adapter.socket.socket",
                   return_value=fake), patch(
                       "reminders.attachment_clamav_adapter.os.lstat",
                       return_value=SimpleNamespace(st_mode=stat.S_IFSOCK | 0o600)):
            verdict = scan_with_clamd(payload=payload, unix_socket="/tmp/synthetic-clamd.sock")
        return verdict, fake

    def test_clean_is_not_signed_or_authorized(self):
        result, fake = self.scan(b"stream: OK\x00")
        self.assertEqual(result.verdict, "clean")
        self.assertEqual(result.reason, "CLAMD_OK_UNATTESTED")
        self.assertTrue(fake.sent.startswith(b"zINSTREAM\x00"))
        self.assertTrue(fake.sent.endswith(b"\x00\x00\x00\x00"))

    def test_infected_and_error_fail_closed(self):
        for answer, expected in (
            (b"stream: Eicar-Test-Signature FOUND\x00", "infected"),
            (b"stream: ERROR\x00", "error"),
            (b"stream: OK", "error"),
            (b"unexpected\x00", "error"),
        ):
            with self.subTest(answer=answer):
                self.assertEqual(self.scan(answer)[0].verdict, expected)

    def test_service_down_and_invalid_settings(self):
        self.assertEqual(self.scan(None, failure=True)[0].verdict, "error")
        self.assertEqual(scan_with_clamd(payload=b"", unix_socket="/tmp/demo").verdict, "error")
        self.assertEqual(scan_with_clamd(payload=b"a", unix_socket="relative").verdict, "error")
        self.assertEqual(scan_with_clamd(payload=b"a", unix_socket="/tmp/demo",
                                         timeout_seconds=0).verdict, "error")

    def test_regular_file_and_symlink_are_not_trusted_sockets(self):
        for mode in (stat.S_IFREG | 0o600, stat.S_IFLNK | 0o777):
            with self.subTest(mode=mode), patch(
                "reminders.attachment_clamav_adapter.os.lstat",
                return_value=SimpleNamespace(st_mode=mode)):
                result = scan_with_clamd(
                    payload=b"synthetic", unix_socket="/tmp/synthetic-clamd.sock")
                self.assertEqual(result.verdict, "error")
                self.assertEqual(result.reason, "UNTRUSTED_SOCKET_PATH")
