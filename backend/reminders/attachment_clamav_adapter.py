"""Opt-in ClamAV INSTREAM adapter for a future isolated scanner.

No automatic connection, no production wiring and no change to download gates.
Use a private Unix domain socket provided by a sandboxed clamd instance.
"""
import socket
import struct
from dataclasses import dataclass

MAX_SCAN_BYTES = 10 * 1024 * 1024


@dataclass(frozen=True)
class ScannerResult:
    verdict: str
    reason: str


def scan_with_clamd(*, payload: bytes, unix_socket: str,
                    timeout_seconds: float = 5.0) -> ScannerResult:
    """Return clean/infected/error; errors ALWAYS reject release.

    Caller must enforce trusted socket path, service identity and scanner
    definition freshness before promoting any attestation.
    """
    if not isinstance(payload, bytes) or not 0 < len(payload) <= MAX_SCAN_BYTES:
        return ScannerResult("error", "INVALID_SIZE")
    if (not isinstance(unix_socket, str) or not unix_socket.startswith("/")
            or len(unix_socket) > 100 or "\x00" in unix_socket
            or not isinstance(timeout_seconds, (int, float))
            or isinstance(timeout_seconds, bool)
            or not 0 < timeout_seconds <= 15):
        return ScannerResult("error", "INVALID_CONFIG")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout_seconds)
            sock.connect(unix_socket)
            sock.sendall(b"zINSTREAM\x00")
            for offset in range(0, len(payload), 65536):
                chunk = payload[offset:offset + 65536]
                sock.sendall(struct.pack(">I", len(chunk)) + chunk)
            sock.sendall(struct.pack(">I", 0))
            reply = bytearray()
            while len(reply) <= 1024:
                chunk = sock.recv(min(256, 1025 - len(reply)))
                if not chunk:
                    break
                reply.extend(chunk)
                if b"\x00" in chunk:
                    break
        if len(reply) > 1024 or not reply.endswith(b"\x00"):
            return ScannerResult("error", "INVALID_RESPONSE")
        raw = bytes(reply[:-1])
        if raw == b"stream: OK":
            return ScannerResult("clean", "CLAMD_OK_UNATTESTED")
        if raw.startswith(b"stream: ") and raw.endswith(b" FOUND"):
            return ScannerResult("infected", "CLAMD_FOUND")
        return ScannerResult("error", "SCAN_FAILED")
    except (OSError, ValueError, OverflowError):
        return ScannerResult("error", "SCANNER_UNAVAILABLE")
