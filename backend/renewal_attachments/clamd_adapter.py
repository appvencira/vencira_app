"""B01: adaptador cerrado para clamd INSTREAM.

No autoriza descargas, no modifica BD y no activa endpoints.
La conexión es por socket Unix local controlado.
"""
import socket
import struct


class MalwareScanUnavailable(Exception):
    pass


class MalwareDetected(Exception):
    pass


def scan_with_clamd(
    content: bytes,
    *,
    socket_path: str,
    timeout: float = 10.0,
) -> None:
    """Devuelve None solo cuando clamd responde exactamente OK.

    La limpieza del archivo no equivale a autorizar su uso.
    """
    if (
        not isinstance(content, bytes)
        or not 0 < len(content) <= 10 * 1024 * 1024
        or not isinstance(socket_path, str)
        or not socket_path.startswith("/")
        or "\x00" in socket_path
        or not isinstance(timeout, (int, float))
        or not 0 < timeout <= 60
    ):
        raise MalwareScanUnavailable("INVALID_SCAN_PARAMETERS")

    try:
        with socket.socket(
            socket.AF_UNIX, socket.SOCK_STREAM
        ) as conn:
            conn.settimeout(timeout)
            conn.connect(socket_path)
            conn.sendall(b"zINSTREAM\x00")

            for start in range(0, len(content), 65536):
                chunk = content[start:start + 65536]
                conn.sendall(struct.pack("!I", len(chunk)))
                conn.sendall(chunk)

            conn.sendall(struct.pack("!I", 0))

            result = bytearray()
            while len(result) <= 512:
                piece = conn.recv(513 - len(result))
                if not piece:
                    break
                result.extend(piece)
                if b"\x00" in result:
                    break

    except (OSError, OverflowError, ValueError) as exc:
        raise MalwareScanUnavailable(
            "SCAN_ENGINE_UNAVAILABLE"
        ) from exc

    if len(result) > 512 or not result.endswith(b"\x00"):
        raise MalwareScanUnavailable("INVALID_ENGINE_REPLY")

    response = bytes(result[:-1])

    if response == b"stream: OK":
        return

    if (
        response.startswith(b"stream: ")
        and response.endswith(b" FOUND")
        and len(response) > len(b"stream:  FOUND")
    ):
        raise MalwareDetected("MALWARE_DETECTED")

    raise MalwareScanUnavailable("SCAN_NOT_CLEAN")
