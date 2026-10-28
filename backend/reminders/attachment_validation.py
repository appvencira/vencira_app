"""Validation primitives for a future PRIVATE, quarantined attachment service.

Does not store data, activate routes, or replace malware inspection.
"""
from pathlib import PurePath
import re

MAX_SYNTHETIC_FILE_BYTES = 10 * 1024 * 1024
ALLOWED = {
    "application/pdf": (".pdf", b"%PDF-"),
    "image/jpeg": (".jpg", b"\xff\xd8\xff"),
    "image/png": (".png", b"\x89PNG\r\n\x1a\n"),
}


def validate_attachment_header(*, filename: str, reported_type: str,
                               header: bytes, size: int) -> tuple[str, str]:
    """Reject malformed input before any persistent write.

    Validation of trailing structure, polyglots, decompression/image bombs and
    malware remains mandatory in the downstream quarantine scanning pipeline.
    """
    if (not isinstance(filename, str) or not isinstance(reported_type, str)
            or not isinstance(header, bytes) or not isinstance(size, int)
            or isinstance(size, bool)):
        raise ValueError("Adjunto inválido")
    if (not 1 <= len(filename) <= 120 or filename in (".", "..")
            or "/" in filename or "\\" in filename or
            any(ord(c) < 32 or ord(c) == 127 for c in filename)):
        raise ValueError("Nombre de adjunto no permitido")
    if not 1 <= size <= MAX_SYNTHETIC_FILE_BYTES:
        raise ValueError("Tamaño de adjunto no permitido")
    if reported_type not in ALLOWED:
        raise ValueError("Formato de adjunto no permitido")
    suffix, magic = ALLOWED[reported_type]
    lower = filename.lower()
    if reported_type == "image/jpeg":
        valid_suffix = lower.endswith((".jpg", ".jpeg"))
    else:
        valid_suffix = lower.endswith(suffix)
    if not valid_suffix or not header.startswith(magic):
        raise ValueError("Contenido o extensión no compatibles")
    # Use generic, bounded filename; strip invisible bidi controls.
    if any(c in filename for c in ("\u202e", "\u202d", "\u2066", "\u2067", "\u2068", "\u2069")):
        raise ValueError("Nombre de adjunto no permitido")
    return filename, reported_type
