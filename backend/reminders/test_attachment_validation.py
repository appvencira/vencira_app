"""Synthetic-only tests. No upload route, storage, or real user files."""
from django.test import SimpleTestCase
from .attachment_validation import (
    MAX_SYNTHETIC_FILE_BYTES, validate_attachment_header,
)


class AttachmentHeaderValidationTests(SimpleTestCase):
    def test_supported_formats(self):
        examples = (
            ("evidence.pdf", "application/pdf", b"%PDF-1.7"),
            ("image.jpg", "image/jpeg", b"\xff\xd8\xff\xe0"),
            ("image.jpeg", "image/jpeg", b"\xff\xd8\xff\xe0"),
            ("photo.png", "image/png", b"\x89PNG\r\n\x1a\n"),
        )
        for name, mime, header in examples:
            with self.subTest(name=name):
                self.assertEqual(
                    validate_attachment_header(
                        filename=name, reported_type=mime, header=header, size=256,
                    ), (name, mime),
                )

    def test_invalid_headers_types_and_names_rejected(self):
        examples = (
            ("../../private.pdf", "application/pdf", b"%PDF-"),
            ("private.pdf", "application/pdf", b"<html>"),
            ("photo.png", "image/jpeg", b"\xff\xd8\xff"),
            ("image.svg", "image/svg+xml", b"<svg>"),
            ("\\private.png", "image/png", b"\x89PNG\r\n\x1a\n"),
            ("evil\u202egnp.pdf", "application/pdf", b"%PDF-"),
            ("evil\n.pdf", "application/pdf", b"%PDF-"),
        )
        for name, mime, header in examples:
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    validate_attachment_header(
                        filename=name, reported_type=mime, header=header, size=100,
                    )

    def test_size_bounds_and_non_integer(self):
        for size in (0, -1, MAX_SYNTHETIC_FILE_BYTES + 1, True, "10"):
            with self.subTest(size=size):
                with self.assertRaises(ValueError):
                    validate_attachment_header(
                        filename="safe.pdf", reported_type="application/pdf",
                        header=b"%PDF-", size=size,
                    )
