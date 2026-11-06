"""G7-D1: isolated Django HTTP issuer behind a real, verified TLS hop.

Laboratory only. Django's LiveServerTestCase creates/destroys a test DB and
runs on loopback; a second loopback-only TLS reverse proxy has a freshly
generated CA and leaf certificate for dev.vencira.es. No network DNS, public
port, checked-in private key, trust bypass, or production routes.
This does NOT exercise Flutter or an Android APK.
"""
import http.client
import json
import socket
import ssl
import tempfile
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from django.contrib.auth import get_user_model
from django.test import LiveServerTestCase, override_settings


_PASSWORD = "G7-D1-Ephemeral-HTTPS-Test-Password-2026!"


class _LoopbackTlsRelay(BaseHTTPRequestHandler):
    """Forward only native lab API routes into Django's live test server."""

    protocol_version = "HTTP/1.1"

    def do_POST(self):
        self._relay()

    def do_GET(self):
        self._relay()

    def _relay(self):
        if not self.path.startswith("/api/v1/mobile/"):
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length < 0 or length > 4096:
                self.send_error(413)
                return
            body = self.rfile.read(length) if length else None
            upstream_headers = {
                key: value for key, value in self.headers.items()
                if key.lower() not in {
                    "host", "connection", "transfer-encoding",
                    "content-length", "accept-encoding",
                }
            }
            upstream_headers["Host"] = "127.0.0.1"
            upstream = http.client.HTTPConnection(
                "127.0.0.1", self.server.upstream_port, timeout=5,
            )
            try:
                upstream.request(
                    self.command, self.path, body=body,
                    headers=upstream_headers,
                )
                response = upstream.getresponse()
                payload = response.read(16385)
                if len(payload) > 16384:
                    self.send_error(502)
                    return
                self.send_response_only(response.status)
                for key, value in response.getheaders():
                    if key.lower() not in {
                        "server", "date", "connection",
                        "content-length", "transfer-encoding",
                    }:
                        self.send_header(key, value)
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(payload)
                self.close_connection = True
            finally:
                upstream.close()
        except (OSError, ValueError, http.client.HTTPException):
            self.close_connection = True
            try:
                self.send_error(502)
            except OSError:
                pass

    def log_message(self, *args):
        # Never log paths, credentials or Authorization headers in this lab.
        pass


def _create_ephemeral_certificates(path):
    now = datetime.now(timezone.utc)
    ca_key = ec.generate_private_key(ec.SECP256R1())
    ca_name = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "Vencira disposable G7-D1 CA"),
    ])
    ca_certificate = (
        x509.CertificateBuilder()
        .subject_name(ca_name)
        .issuer_name(ca_name)
        .public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=2))
        .not_valid_after(now + timedelta(hours=1))
        .add_extension(
            x509.BasicConstraints(ca=True, path_length=0), critical=True,
        )
        .add_extension(
            x509.KeyUsage(
                digital_signature=False,
                content_commitment=False,
                key_encipherment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=True,
                crl_sign=True,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        )
        .sign(ca_key, hashes.SHA256())
    )
    leaf_key = ec.generate_private_key(ec.SECP256R1())
    leaf_certificate = (
        x509.CertificateBuilder()
        .subject_name(x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "dev.vencira.es"),
        ]))
        .issuer_name(ca_name)
        .public_key(leaf_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(minutes=2))
        .not_valid_after(now + timedelta(minutes=45))
        .add_extension(
            x509.BasicConstraints(ca=False, path_length=None), critical=True,
        )
        .add_extension(
            x509.SubjectAlternativeName([
                x509.DNSName("dev.vencira.es"),
            ]),
            critical=False,
        )
        .add_extension(
            x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),
            critical=False,
        )
        .sign(ca_key, hashes.SHA256())
    )

    ca = path / "ephemeral-ca.pem"
    leaf = path / "ephemeral-server.pem"
    key = path / "ephemeral-server.key"
    ca.write_bytes(ca_certificate.public_bytes(serialization.Encoding.PEM))
    leaf.write_bytes(leaf_certificate.public_bytes(serialization.Encoding.PEM))
    key.write_bytes(leaf_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ))
    key.chmod(0o600)
    return ca, leaf, key


@override_settings(ROOT_URLCONF="native_sessions_lab.test_urls")
class NativeVerifiedHttpsLoopbackTests(LiveServerTestCase):
    host = "127.0.0.1"

    def setUp(self):
        super().setUp()
        self.user = get_user_model().objects.create_user(
            username="g7-d1-https-synthetic", password=_PASSWORD,
        )
        self._temp_dir = tempfile.TemporaryDirectory(prefix="vencira-g7-d1-")
        ca, leaf, key = _create_ephemeral_certificates(
            Path(self._temp_dir.name),
        )
        self._ca_path = str(ca)
        backend = urlsplit(self.live_server_url)
        self.assertEqual(backend.hostname, "127.0.0.1")
        self.assertEqual(backend.scheme, "http")

        server = ThreadingHTTPServer(
            ("127.0.0.1", 0), _LoopbackTlsRelay,
        )
        server.daemon_threads = True
        server.upstream_port = backend.port
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(str(leaf), str(key))
        server.socket = context.wrap_socket(server.socket, server_side=True)
        self._tls_server = server
        self._tls_port = server.server_address[1]
        self._thread = threading.Thread(
            target=server.serve_forever,
            kwargs={"poll_interval": 0.02}, daemon=True,
        )
        self._thread.start()

    def tearDown(self):
        self._tls_server.shutdown()
        self._tls_server.server_close()
        self._thread.join(timeout=5)
        self._temp_dir.cleanup()
        super().tearDown()

    def _client(self, *, hostname="dev.vencira.es", trusted=True):
        context = ssl.create_default_context(
            cafile=self._ca_path if trusted else None,
        )
        context.check_hostname = True
        context.verify_mode = ssl.CERT_REQUIRED
        # Connect ONLY to the loopback listener; set SNI/hostname separately.
        plain = socket.create_connection(
            ("127.0.0.1", self._tls_port), timeout=5,
        )
        return context.wrap_socket(plain, server_hostname=hostname)

    def _request(self, method, path, data=None, headers=None):
        self.assertTrue(path.startswith("/api/v1/mobile/"))
        body = None if data is None else json.dumps(data).encode("utf-8")
        request_headers = {"Accept": "application/json"}
        if body is not None:
            request_headers["Content-Type"] = "application/json"
        request_headers.update(headers or {})
        # http.client normally connects to DNS. Override connect() so the
        # TLS SAN still validates dev.vencira.es, but the actual socket never
        # leaves 127.0.0.1.
        connection = http.client.HTTPSConnection(
            "dev.vencira.es", self._tls_port, timeout=5,
        )
        # Supply the already-verified loopback TLS socket directly, so
        # HTTPSConnection never performs hostname lookup or outbound connect.
        connection.sock = self._client()
        try:
            connection.request(method, path, body=body, headers=request_headers)
            response = connection.getresponse()
            status = response.status
            response_headers = {
                k.lower(): v for k, v in response.getheaders()
            }
            raw = response.read(16385)
            self.assertLessEqual(len(raw), 16384)
            self.assertIn(
                "application/json", response_headers.get("content-type", ""),
            )
            return status, response_headers, json.loads(raw.decode("utf-8"))
        finally:
            connection.close()

    def _password(self):
        return self._request("POST", "/api/v1/mobile/auth/password/", {
            "username": self.user.username, "password": _PASSWORD,
        })

    def test_verified_tls_password_bearer_and_revocation(self):
        status, headers, granted = self._password()
        self.assertEqual(status, 200)
        self.assertEqual(granted["status"], "authenticated")
        self.assertTrue(granted["access"].startswith("v1.a."))
        self.assertTrue(granted["refresh"].startswith("v1.r."))
        self.assertIn("no-store", headers.get("cache-control", ""))
        self.assertNotIn("set-cookie", headers)

        status, _, profile = self._request(
            "GET", "/api/v1/mobile/me/",
            headers={"Authorization": "Bearer " + granted["access"]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(profile, {
            "authenticated": True,
            "user_id": self.user.pk,
        })

        status, _, revoked = self._request(
            "POST", "/api/v1/mobile/token/revoke/",
            {"refresh": granted["refresh"]},
        )
        self.assertEqual(status, 200)
        self.assertEqual(revoked, {"status": "revoked"})
        status, _, denied = self._request(
            "GET", "/api/v1/mobile/me/",
            headers={"Authorization": "Bearer " + granted["access"]},
        )
        self.assertEqual(status, 401)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})

    def test_tls_hostname_and_trust_are_required(self):
        # Neither a different hostname nor an untrusted CA can complete
        # an HTTPS session. No disable-verification callback is permitted.
        with self.assertRaises(ssl.SSLCertVerificationError):
            with self._client(hostname="vencira.es"):
                pass
        with self.assertRaises(ssl.SSLCertVerificationError):
            with self._client(trusted=False):
                pass

    def test_verified_tls_browser_credentials_stay_rejected(self):
        data = {"username": self.user.username, "password": _PASSWORD}
        status, _, denied = self._request(
            "POST", "/api/v1/mobile/auth/password/", data,
            headers={"Cookie": "vencira_sessionid=synthetic"},
        )
        self.assertEqual(status, 403)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})
        status, _, denied = self._request(
            "POST", "/api/v1/mobile/auth/password/", data,
            headers={"Origin": "https://untrusted.invalid"},
        )
        self.assertEqual(status, 403)
        self.assertEqual(denied, {"error": "native_auth_unavailable"})
