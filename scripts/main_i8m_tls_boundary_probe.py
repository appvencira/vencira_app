"""I8-M isolated, credential-free real HTTPS handshake and URL boundary.

Only connects to a Docker-local synthetic TLS service. Does not send auth,
TOTP, bearer tokens, passwords, refresh credentials, cookies or user data.
"""
import os
import socket
import ssl
import urllib.error
import urllib.request

HOST = "native-i8k.test"
BASE = f"https://{HOST}:8443"
CA_PATH = "/tmp/i8m-public-cert.pem"

if os.getenv("VENCIRA_I8M_INTERNAL_TLS_PROBE") != "1":
    raise SystemExit("MAIN_I8M_TLS_NETWORK_GUARD=DENIED")
if os.getenv("VENCIRA_ENV") != "test" or os.getenv("POSTGRES_DB") != "i8klab":
    raise SystemExit("MAIN_I8M_TLS_ENV_GUARD=DENIED")

def opener(context):
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),
    )

trusted_context = ssl.create_default_context(cafile=CA_PATH)
trusted = opener(trusted_context)
untrusted = opener(ssl.create_default_context())

try:
    untrusted.open(BASE + "/api/v1/mobile/me/", timeout=8)
except urllib.error.URLError as error:
    if not isinstance(error.reason, ssl.SSLCertVerificationError):
        raise
    print("MAIN_I8M_REAL_UNTRUSTED_CA_DENIED=PASS", flush=True)
else:
    raise AssertionError("untrusted CA accepted")

raw = socket.create_connection((HOST, 8443), timeout=8)
try:
    try:
        with trusted_context.wrap_socket(
            raw, server_hostname="wrong-i8m.invalid",
        ):
            raise AssertionError("hostname mismatch accepted")
    except ssl.SSLCertVerificationError:
        print("MAIN_I8M_REAL_HOSTNAME_MISMATCH_DENIED=PASS", flush=True)
finally:
    raw.close()

def request(path):
    req = urllib.request.Request(
        BASE + path, method="GET", headers={"Accept": "application/json"}
    )
    try:
        with trusted.open(req, timeout=8) as response:
            return response.status, response.headers, response.read(8193)
    except urllib.error.HTTPError as error:
        return error.code, error.headers, error.read(8193)

for path, expected in (
    ("/api/v1/mobile/auth/recover/password/", 405),
    ("/api/v1/mobile/auth/recover/mfa/", 405),
    ("/api/v1/mobile/token/revoke/", 405),
    ("/api/v1/mobile/me/", 401),
    ("/api/v1/mobile/auth/password/", 404),
):
    status, headers, data = request(path)
    if status != expected:
        raise AssertionError(f"unexpected response on {path}: {status}")
    if headers.get("Set-Cookie") is not None:
        raise AssertionError("native test endpoint issued a cookie")
    if expected != 404:
        if headers.get("Cache-Control") != "no-store, max-age=0":
            raise AssertionError("unexpected native cache policy")
        if headers.get_content_type() != "application/json":
            raise AssertionError("native boundary is not JSON")
    # The absent ordinary-login route uses Django's default 404 response,
    # which is intentionally not required to be native JSON.
    if len(data) > 8192:
        raise AssertionError("oversized native denial")
print("MAIN_I8M_REAL_HTTPS_DJANGO_BOUNDARY=PASS", flush=True)
print("MAIN_I8M_REAL_TLS_PYTHON_CLIENT_SERVER=PASS", flush=True)
print("MAIN_I8M_REAL_TLS_FLUTTER_CLIENT=NOT_TESTED", flush=True)
print("MAIN_I8M_REAL_MFA_FLOW=NOT_TESTED", flush=True)
print("MAIN_I8M_ANDROID_PERSISTENCE=NOT_TESTED", flush=True)
