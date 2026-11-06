"""Conservative structure preinspection of synthetic PDF/JPEG/PNG.

This is NOT antivirus or an attestation. All outcomes remain quarantined;
there is no path from this component to downloadable 'clean' objects.
"""
import struct
import zlib
from dataclasses import dataclass

from .attachment_validation import MAX_SYNTHETIC_FILE_BYTES, validate_attachment_header


@dataclass(frozen=True)
class Preinspection:
    structurally_valid: bool
    reason: str
    release_allowed: bool = False


def preinspect(*, filename: str, reported_type: str, data: bytes) -> Preinspection:
    if not isinstance(data, bytes) or not 0 < len(data) <= MAX_SYNTHETIC_FILE_BYTES:
        return Preinspection(False, "INVALID_SIZE")
    try:
        validate_attachment_header(filename=filename, reported_type=reported_type,
                                   header=data[:16], size=len(data))
    except ValueError:
        return Preinspection(False, "INVALID_HEADER")
    if reported_type == "application/pdf":
        # Conservative sanity check only. A PDF parser and malware/active
        # content policy are REQUIRED before anyone can mark it clean.
        valid = data.rstrip().endswith(b"%%EOF") and b"startxref" in data
        return Preinspection(valid, "PDF_NEEDS_SANDBOX_SCAN" if valid else "PDF_INCOMPLETE")
    if reported_type == "image/png":
        return _png(data)
    if reported_type == "image/jpeg":
        valid = data.endswith(b"\xff\xd9") and len(data) >= 8
        return Preinspection(valid, "JPEG_NEEDS_DECODER_SCAN" if valid else "JPEG_INCOMPLETE")
    return Preinspection(False, "UNKNOWN_TYPE")


def _png(data: bytes) -> Preinspection:
    pos = 8
    width = height = None
    saw_iend = False
    try:
        while pos + 12 <= len(data):
            length = struct.unpack(">I", data[pos:pos + 4])[0]
            if length > 10 * 1024 * 1024 or pos + length + 12 > len(data):
                return Preinspection(False, "PNG_BAD_CHUNK")
            kind = data[pos + 4:pos + 8]
            payload = data[pos + 8:pos + 8 + length]
            checksum = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])[0]
            if zlib.crc32(kind + payload) & 0xffffffff != checksum:
                return Preinspection(False, "PNG_BAD_CRC")
            if width is None:
                if kind != b"IHDR" or length != 13:
                    return Preinspection(False, "PNG_BAD_IHDR")
                width, height = struct.unpack(">II", payload[:8])
                if not width or not height or width * height > 16_000_000:
                    return Preinspection(False, "PNG_DIMENSIONS")
            pos += length + 12
            if kind == b"IEND":
                saw_iend = (length == 0 and pos == len(data))
                break
    except (ValueError, struct.error):
        return Preinspection(False, "PNG_PARSE_ERROR")
    return Preinspection(saw_iend, "PNG_NEEDS_DECODER_SCAN" if saw_iend else "PNG_INCOMPLETE")
