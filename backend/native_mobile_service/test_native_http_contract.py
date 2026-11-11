"""D19 native JSON envelope contract; no network, database or token issuance."""
import json

from django.test import RequestFactory, SimpleTestCase

from .native_http_contract import (
    MAX_NATIVE_JSON_BODY,
    native_auth_denied,
    native_json_response,
    parse_native_json,
)


class NativeJsonEnvelopeTests(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def parse(self, text, fields=("username", "password"), *,
              content_type="application/json"):
        request = self.factory.post(
            "/api/v1/mobile/auth/password/",
            data=text, content_type=content_type,
        )
        return parse_native_json(request, tuple(fields))

    def test_valid_exact_non_ascii_password_and_no_echo(self):
        data = '{"username":"usuario","password":"clave ñ"}'
        self.assertEqual(self.parse(data),
                         {"username": "usuario", "password": "clave ñ"})

    def test_reject_duplicate_keys_instead_of_last_value_wins(self):
        self.assertIsNone(self.parse(
            '{"username":"first","username":"second","password":"x"}'
        ))
        self.assertIsNone(self.parse(
            '{"username":"a","password":"a","password":"b"}'
        ))

    def test_reject_missing_extra_and_wrong_typed_fields(self):
        for value in (
            '{"username":"a"}',
            '{"username":"a","password":"b","roles":"admin"}',
            '{"username":"a","password":null}',
            '{"username":2,"password":"b"}',
            '["a","b"]',
            'null',
            '"string"',
        ):
            with self.subTest(body=value):
                self.assertIsNone(self.parse(value))

    def test_reject_non_json_malformed_and_nonfinite(self):
        self.assertIsNone(self.parse(
            '{"username":"a","password":"b"}',
            content_type="text/plain",
        ))
        for value in (
            '{"username":"a","password":NaN}',
            '{"username":"a","password":Infinity}',
            '{"username":"a","password":"b",}',
            '',
            '{"username":"a","password":"b"} garbage',
        ):
            self.assertIsNone(self.parse(value))

    def test_reject_noncanonical_input_and_bounded_body(self):
        self.assertIsNone(self.parse(" " * (MAX_NATIVE_JSON_BODY + 1)))
        self.assertIsNone(self.parse('{"username":"a","password":"b"}',
                                    fields=("username", "username")))
        request = self.factory.post(
            "/api/v1/mobile/auth/password/",
            data=b'{"username":"a","password":"\\xff"}',
            content_type="application/json",
        )
        self.assertIsNone(parse_native_json(request, ("username", "password")))

    def test_denials_do_not_echo_inputs_or_cache(self):
        response = native_auth_denied(status=401)
        self.assertEqual(response.status_code, 401)
        self.assertEqual(json.loads(response.content),
                         {"error": "native_auth_unavailable"})
        self.assertEqual(response["Cache-Control"], "no-store, max-age=0")
        self.assertEqual(response["X-Content-Type-Options"], "nosniff")
        self.assertNotIn("Set-Cookie", response)

    def test_native_response_has_no_cookie_and_is_nostore(self):
        response = native_json_response({"status": "mfa_required"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Pragma"], "no-cache")
        self.assertNotIn("Set-Cookie", response)
