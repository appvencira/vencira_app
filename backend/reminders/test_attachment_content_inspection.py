"""Preinspection never marks objects safe for download."""
import struct
import zlib
from django.test import SimpleTestCase
from .attachment_content_inspection import preinspect


def png_chunk(kind, data):
    return (struct.pack(">I", len(data)) + kind + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))


def synthetic_png():
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr)
            + png_chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00"))
            + png_chunk(b"IEND", b""))


class PreinspectionTests(SimpleTestCase):
    def test_png_structure_never_unlocks_download(self):
        result = preinspect(filename="demo.png", reported_type="image/png", data=synthetic_png())
        self.assertTrue(result.structurally_valid)
        self.assertFalse(result.release_allowed)

    def test_corrupted_and_trailing_png_rejected(self):
        good = synthetic_png()
        for content in (good[:-1], good + b"junk", good[:30] + b"X" + good[31:]):
            with self.subTest(length=len(content)):
                result = preinspect(filename="demo.png", reported_type="image/png", data=content)
                self.assertFalse(result.release_allowed)
                self.assertFalse(result.structurally_valid)

    def test_pdf_never_unlocks_download(self):
        for data, expected in (
            (b"%PDF-1.7\nstartxref\n1\n%%EOF", True),
            (b"%PDF-1.7", False),
        ):
            result = preinspect(filename="demo.pdf", reported_type="application/pdf", data=data)
            self.assertEqual(result.structurally_valid, expected)
            self.assertFalse(result.release_allowed)

    def test_invalid_jpeg_and_svg_rejected(self):
        for name, mime, content in (
            ("pic.jpg", "image/jpeg", b"\xff\xd8\xff\xe0X"),
            ("demo.svg", "image/svg+xml", b"<svg/>"),
        ):
            result = preinspect(filename=name, reported_type=mime, data=content)
            self.assertFalse(result.structurally_valid)
            self.assertFalse(result.release_allowed)

    def test_size_limit(self):
        result = preinspect(filename="a.pdf", reported_type="application/pdf",
                            data=b"%PDF-" + b"0" * (10 * 1024 * 1024))
        self.assertFalse(result.structurally_valid)
        self.assertFalse(result.release_allowed)
