"""Real HTTPS client for the operational login and MFA routes in an isolated lab."""
import http.cookiejar
import json
import os
import ssl
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://login-mfa.test:8443"
CERT = "/tmp/login-mfa-cert.pem"
SECRET = os.environ["VENCIRA_MFA_LAB_TOTP_SECRET"]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def browser():
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPSHandler(context=ssl.create_default_context(cafile=CERT)),
        urllib.request.HTTPCookieProcessor(jar),
        NoRedirect(),
    )
    return opener, jar


def req(browser_, path, *, method="GET", fields=None, csrf=None):
    opener, _ = browser_
    headers = {}
    body = None
    if fields is not None:
        body = urllib.parse.urlencode(fields).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    if method == "POST":
        headers["Origin"] = BASE
        headers["Referer"] = BASE + path
        if csrf is not None:
            headers["X-CSRFToken"] = csrf
    request = urllib.request.Request(BASE + path, method=method, data=body, headers=headers)
    try:
        with opener.open(request, timeout=15) as response:
            return response.status, response.read(), response.headers
    except urllib.error.HTTPError as error:
        return error.code, error.read(), error.headers


def csrf(browser_):
    code, body, _ = req(browser_, "/api/v1/csrf/")
    assert code == 200, (code, body[:100])
    return json.loads(body)["csrfToken"]


def login(browser_, username, password, csrf_token):
    return req(
        browser_, "/accounts/login/", method="POST",
        fields={"username": username, "password": password, "csrfmiddlewaretoken": csrf_token},
        csrf=csrf_token,
    )


def denied(browser_):
    code, body, _ = req(browser_, "/api/v1/me/")
    assert code in (401, 403), (code, body[:120])


def secure_cookies(browser_):
    _, jar = browser_
    items = {item.name: item for item in jar}
    assert items["vencira_sessionid"].secure, items
    assert "HttpOnly" in items["vencira_sessionid"]._rest, items
    assert items["vencira_csrftoken"].secure, items


# TLS rejects an untrusted certificate, even with a reachable isolated host.
untrusted = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=ssl.create_default_context()),
)
try:
    untrusted.open(BASE + "/api/health/", timeout=8)
except urllib.error.URLError as error:
    assert isinstance(error.reason, ssl.SSLCertVerificationError), error
    print("LOGIN_MFA_HTTPS_UNTRUSTED_CA_DENIED=PASS")
else:
    raise AssertionError("untrusted TLS cert accepted")

basic = browser()
assert req(basic, "/api/health/")[0] == 200
denied(basic)
print("LOGIN_MFA_HTTPS_TLS_AND_ANONYMOUS_DENIAL=PASS")
first_csrf = csrf(basic)
code, body, _ = login(basic, "https-basic", "synthetic-https-password-2026", None)
assert code == 403, (code, body[:120])
denied(basic)
code, body, headers = login(basic, "https-basic", "synthetic-https-password-2026", first_csrf)
assert code == 302 and headers.get("Location") == "/api/v1/me/", (code, headers.get("Location"))
secure_cookies(basic)
assert req(basic, "/api/v1/me/")[0] == 200
print("LOGIN_MFA_HTTPS_PASSWORD_ONLY_ACCOUNT=PASS")

mfa = browser()
token = csrf(mfa)
code, body, headers = login(mfa, "https-mfa", "synthetic-https-password-2026", token)
assert code == 302 and headers.get("Location") == "/accounts/mfa/", (code, headers.get("Location"))
denied(mfa)
print("LOGIN_MFA_HTTPS_PASSWORD_DOES_NOT_BYPASS_MFA=PASS")
assert req(mfa, "/accounts/mfa/")[0] == 200

# Without a CSRF token, the challenge must reject the request.
code, body, _ = req(mfa, "/accounts/mfa/", method="POST", fields={"code": "000000"})
assert code == 403, (code, body[:120])
denied(mfa)
print("LOGIN_MFA_HTTPS_CHALLENGE_CSRF_DENIED=PASS")

from reminders.mfa_totp import totp_at
import time
token = csrf(mfa)
correct = totp_at(SECRET, int(time.time()))
bad = "000000" if correct != "000000" else "111111"
code, body, _ = req(mfa, "/accounts/mfa/", method="POST", fields={"code": bad}, csrf=token)
assert code == 403, (code, body[:120])
denied(mfa)
code, body, headers = req(mfa, "/accounts/mfa/", method="POST",
                           fields={"code": totp_at(SECRET, int(time.time()))}, csrf=csrf(mfa))
assert code == 302 and headers.get("Location") == "/api/v1/me/", (code, headers.get("Location"), body[:100])
secure_cookies(mfa)
assert req(mfa, "/api/v1/me/")[0] == 200
print("LOGIN_MFA_HTTPS_TOTP_SESSION_VERIFIED=PASS")

# The consumed pending challenge is not usable a second time.
code, body, headers = req(mfa, "/accounts/mfa/", method="POST",
                           fields={"code": totp_at(SECRET, int(time.time()))}, csrf=csrf(mfa))
assert code == 302 and headers.get("Location") == "/accounts/login/", (code, headers.get("Location"))
print("LOGIN_MFA_HTTPS_PENDING_CHALLENGE_SINGLE_USE=PASS")
print("LOGIN_MFA_HTTPS_TRANSPORT_GATE=PASS")
