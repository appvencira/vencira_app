"""I8-K: independent verified TLS client for recovery-only synthetic PG17."""
import json
import os
import socket
import ssl
import time
import urllib.error
import urllib.request

from reminders.mfa_totp import totp_at

HOST = "native-i8k.test"
BASE = "https://" + HOST + ":8443"
CA = "/tmp/i8k-cert.pem"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def opener(context):
    return urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=context),
        NoRedirect(),
    )


trusted = opener(ssl.create_default_context(cafile=CA))
untrusted = opener(ssl.create_default_context())

try:
    untrusted.open(BASE + "/api/v1/mobile/me/", timeout=6)
except urllib.error.URLError as exc:
    assert isinstance(exc.reason, ssl.SSLCertVerificationError), type(exc.reason)
    print("NATIVE_I8K_UNTRUSTED_CA_DENIED=PASS")
else:
    raise AssertionError("untrusted CA accepted")

try:
    raw = socket.create_connection((HOST, 8443), timeout=6)
    with ssl.create_default_context(cafile=CA).wrap_socket(
        raw, server_hostname="wrong-i8k-host.invalid",
    ):
        pass
except ssl.SSLCertVerificationError:
    print("NATIVE_I8K_HOSTNAME_MISMATCH_DENIED=PASS")
else:
    raise AssertionError("hostname mismatch accepted")


def request(path, data=None, headers=None):
    body = json.dumps(data).encode("utf-8") if data is not None else None
    fields = {"Accept": "application/json", **(headers or {})}
    if body is not None:
        fields["Content-Type"] = "application/json"
    req = urllib.request.Request(
        BASE + path, data=body, headers=fields,
        method="POST" if body is not None else "GET",
    )
    try:
        with trusted.open(req, timeout=15) as res:
            status, data, hdr = res.status, res.read(), res.headers
    except urllib.error.HTTPError as err:
        status, data, hdr = err.code, err.read(), err.headers
    assert not hdr.get_all("Set-Cookie", []), "unexpected cookie issuance"
    assert hdr.get("Cache-Control") == "no-store, max-age=0"
    assert hdr.get_content_type() == "application/json"
    return status, json.loads(data)


password_path = "/api/v1/mobile/auth/recover/password/"
mfa_path = "/api/v1/mobile/auth/recover/mfa/"
me_path = "/api/v1/mobile/me/"

status, data = request(password_path, {
    "username": "i8k-unknown", "password": "invalid",
})
assert status == 401 and data == {"error": "native_auth_unavailable"}
print("NATIVE_I8K_UNKNOWN_ACCOUNT_DENIED=PASS")

status, data = request(password_path, {
    "username": "i8k-recovery-synthetic",
    "password": "synthetic-i8k-password",
})
assert status == 200 and set(data) == {"status", "challenge"}, (status, data.keys())
assert data["status"] == "mfa_required"
challenge = data["challenge"]
assert challenge.startswith("lc1.")
print("NATIVE_I8K_PASSWORD_RECOVERY_CHALLENGE_ONLY=PASS")

correct = totp_at(os.environ["VENCIRA_I8K_MFA_SECRET"], int(time.time()))
wrong = "000000" if correct != "000000" else "111111"
status, data = request(mfa_path, {"challenge": challenge, "code": wrong})
assert status == 401 and data == {"error": "native_auth_unavailable"}
print("NATIVE_I8K_WRONG_TOTP_DENIED=PASS")

status, pair = request(mfa_path, {
    "challenge": challenge,
    "code": totp_at(os.environ["VENCIRA_I8K_MFA_SECRET"], int(time.time())),
})
assert status == 200 and set(pair) == {"status", "access", "refresh"}, (status, pair.keys())
assert pair["status"] == "authenticated"
print("NATIVE_I8K_TLS_ATOMIC_RECOVERY_ISSUED=PASS")

status, me = request(me_path, headers={"Authorization": "Bearer " + pair["access"]})
assert status == 200 and me["authenticated"] is True
print("NATIVE_I8K_RECOVERED_BEARER_ME=PASS")

status, _ = request(mfa_path, {"challenge": challenge, "code": correct})
assert status == 401
print("NATIVE_I8K_RECOVERY_CHALLENGE_REPLAY_DENIED=PASS")

try:
    trusted.open(urllib.request.Request(
        BASE + "/api/v1/mobile/auth/password/", method="GET",
    ), timeout=6)
except urllib.error.HTTPError as err:
    assert err.code == 404
    print("NATIVE_I8K_NORMAL_LOGIN_ENDPOINT_ABSENT=PASS")
else:
    raise AssertionError("normal login unexpectedly routed")

status, _ = request(password_path, {
    "username": "i8k-recovery-synthetic", "password": "synthetic-i8k-password",
}, headers={"Origin": "https://untrusted.invalid"})
assert status == 403
print("NATIVE_I8K_BROWSER_ORIGIN_DENIED=PASS")
print("NATIVE_I8K_REAL_HTTPS_GATE=PASS")
