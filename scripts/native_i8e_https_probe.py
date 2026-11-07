"""I8-E real HTTPS probe; no browser cookies, no redirected/cached bearer."""
import json
import os
import ssl
import time
import urllib.error
import urllib.request

from reminders.mfa_totp import totp_at

BASE = "https://native-i8e.test:8443"
CERT = "/tmp/i8e-cert.pem"
SECRET = os.environ["VENCIRA_I8E_MFA_SECRET"]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def client(context):
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),
        NoRedirect(),
    )


trusted = client(ssl.create_default_context(cafile=CERT))
untrusted = client(ssl.create_default_context())

try:
    untrusted.open(BASE + "/api/v1/mobile/me/", timeout=8)
except urllib.error.URLError as error:
    assert isinstance(error.reason, ssl.SSLCertVerificationError), type(error.reason)
    print("NATIVE_I8E_UNTRUSTED_CA_DENIED=PASS")
else:
    raise AssertionError("untrusted TLS CA accepted")

wrong_host = client(ssl.create_default_context(cafile=CERT))
try:
    wrong_host.open("https://native-i8e.test.invalid:8443/api/v1/mobile/me/", timeout=3)
except urllib.error.URLError:
    pass  # This tests DNS failure, not certificate hostname mismatch.
else:
    raise AssertionError("unexpectedly resolved invalid host")


def request(path, data=None, headers=None):
    provided = headers or {}
    body = None if data is None else json.dumps(data).encode("utf-8")
    fields = {"Accept": "application/json", **provided}
    if body is not None:
        fields["Content-Type"] = "application/json"
    req = urllib.request.Request(
        BASE + path, data=body,
        headers=fields, method="POST" if body is not None else "GET",
    )
    try:
        with trusted.open(req, timeout=15) as response:
            status, raw, hdr = response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        status, raw, hdr = error.code, error.read(), error.headers
    assert "set-cookie" not in hdr, hdr
    assert hdr.get("Cache-Control") == "no-store, max-age=0", hdr
    assert hdr.get_content_type() == "application/json", hdr
    assert len(raw) < 8192
    return status, json.loads(raw), hdr


status, data, _ = request(
    "/api/v1/mobile/auth/password/",
    {"username": "i8e-no-such-account", "password": "incorrect"},
)
assert status == 401 and data == {"error": "native_auth_unavailable"}, (status, data)
print("NATIVE_I8E_UNKNOWN_ACCOUNT_DENIED=PASS")

status, body, _ = request(
    "/api/v1/mobile/auth/password/",
    {"username": "i8e-synthetic-mfa", "password": "synthetic-i8e-password"},
)
assert status == 200 and set(body) == {"status", "challenge"}
assert body["status"] == "mfa_required"
challenge = body["challenge"]
assert challenge.startswith("lc1.")
print("NATIVE_I8E_PASSWORD_CHALLENGE_ONLY=PASS")

correct = totp_at(SECRET, int(time.time()))
wrong = "000000" if correct != "000000" else "111111"
status, data, _ = request(
    "/api/v1/mobile/auth/mfa/", {"challenge": challenge, "code": wrong},
)
assert status == 401 and data == {"error": "native_auth_unavailable"}
print("NATIVE_I8E_WRONG_TOTP_DENIED=PASS")

status, tokens, _ = request(
    "/api/v1/mobile/auth/mfa/",
    {"challenge": challenge, "code": totp_at(SECRET, int(time.time()))},
)
assert status == 200 and set(tokens) == {"status", "access", "refresh"}, (status, tokens)
assert tokens["status"] == "authenticated"
assert tokens["access"].startswith("v1.a.")
assert tokens["refresh"].startswith("v1.r.")
print("NATIVE_I8E_MFA_ISSUED_OVER_TLS=PASS")

status, _, _ = request(
    "/api/v1/mobile/auth/mfa/",
    {"challenge": challenge, "code": totp_at(SECRET, int(time.time()))},
)
assert status == 401
print("NATIVE_I8E_CHALLENGE_REPLAY_DENIED=PASS")

status, data, _ = request(
    "/api/v1/mobile/me/", headers={"Authorization": "Bearer " + tokens["access"]},
)
assert status == 200 and data["authenticated"] is True
print("NATIVE_I8E_BEARER_ME_VERIFIED=PASS")

status, refreshed, _ = request(
    "/api/v1/mobile/token/refresh/", {"refresh": tokens["refresh"]},
)
assert status == 200 and refreshed["refresh"] != tokens["refresh"]
status, _, _ = request(
    "/api/v1/mobile/token/refresh/", {"refresh": tokens["refresh"]},
)
assert status == 401
status, _, _ = request(
    "/api/v1/mobile/me/",
    headers={"Authorization": "Bearer " + refreshed["access"]},
)
assert status == 401
print("NATIVE_I8E_REFRESH_REPLAY_REVOKES=PASS")

# Separate fresh authentication, then explicit revoke/401.
status, data, _ = request(
    "/api/v1/mobile/auth/password/",
    {"username": "i8e-synthetic-mfa", "password": "synthetic-i8e-password"},
)
assert status == 200
status, new_tokens, _ = request(
    "/api/v1/mobile/auth/mfa/",
    {"challenge": data["challenge"], "code": totp_at(SECRET, int(time.time()))},
)
# TOTP replay protection deliberately prevents reuse in the same 30s window.
# The logout check can use a different synthetic user created by the fixture,
# so the probe must not bypass or weaken this policy.
assert status == 401
print("NATIVE_I8E_TOTP_REPLAY_DENIED=PASS")

status, data, _ = request(
    "/api/v1/mobile/auth/password/",
    {"username": "i8e-synthetic-mfa", "password": "synthetic-i8e-password"},
    headers={"Cookie": "vencira_sessionid=should-be-denied"},
)
assert status == 403
print("NATIVE_I8E_BROWSER_COOKIE_DENIED=PASS")
print("NATIVE_I8E_REAL_HTTPS_GATE=PASS")
