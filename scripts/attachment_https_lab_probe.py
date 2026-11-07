"""HTTPS transport probe using real TLS, HTTP cookie jar and a disposable user."""
import http.cookiejar
import json
import ssl
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://attachment.test:8443"
WS = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
REN = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
ATT = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
PATH = f"/api/v1/workspaces/{WS}/renewals/{REN}/attachments/"
CA = "/tmp/attachment-lab-cert.pem"

# A self-signed test certificate must NEVER be accepted by the default store.
untrusted = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=ssl.create_default_context()),
)
try:
    untrusted.open(BASE + "/api/health/", timeout=5)
except urllib.error.URLError as error:
    assert isinstance(error.reason, ssl.SSLCertVerificationError), error
    print("ATT_HTTPS_UNTRUSTED_CA_DENIED=PASS")
else:
    raise AssertionError("Untrusted certificate was accepted")

ctx = ssl.create_default_context(cafile=CA)
ctx.check_hostname = True
jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(
    urllib.request.ProxyHandler({}),
    urllib.request.HTTPSHandler(context=ctx),
    urllib.request.HTTPCookieProcessor(jar),
)

def request(path, method="GET", data=None, headers=None):
    payload = None
    if data is not None:
        payload = data if isinstance(data, bytes) else data.encode("utf-8")
    req = urllib.request.Request(BASE + path, data=payload, method=method,
                                 headers=headers or {})
    try:
        with opener.open(req, timeout=12) as response:
            return response.status, response.read(), dict(response.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read(), dict(error.headers)

status, raw, _ = request("/api/health/")
assert status == 200, status
print("ATT_HTTPS_CERTIFICATE_AND_HOSTNAME=PASS")
status, raw, _ = request(PATH)
assert status in (401, 403), (status, raw[:100])
print("ATT_HTTPS_UNAUTHENTICATED_DENIED=PASS")
status, raw, _ = request("/api/v1/csrf/")
assert status == 200, (status,raw)
csrf = json.loads(raw)["csrfToken"]
cookies = {c.name: c for c in jar}
assert cookies["vencira_csrftoken"].secure, cookies
login = urllib.parse.urlencode({
    "username": "att-https-owner",
    "password": "disposable-only-attachment-https-password-2026",
    "csrfmiddlewaretoken": csrf,
}).encode("utf-8")
status, raw, headers = request(
    "/_att_lab/login/", "POST", login, {
        "Content-Type": "application/x-www-form-urlencoded",
        "Origin": BASE,
        "Referer": BASE + "/_att_lab/login/",
        "X-CSRFToken": csrf,
    })
assert status == 200 and json.loads(raw).get("lab") == "authenticated", (status,raw[:240])
cookies = {c.name:c for c in jar}
assert cookies["vencira_sessionid"].secure, cookies
assert "HttpOnly" in cookies["vencira_sessionid"]._rest, cookies
assert cookies["vencira_csrftoken"].secure, cookies
print("ATT_HTTPS_TEST_ONLY_PASSWORD_SESSION_SECURE_COOKIES=PASS")
status, raw, headers = request(PATH)
assert status == 200, (status,raw[:240])
doc=json.loads(raw)
assert len(doc["results"]) == 1,doc
assert doc["results"][0]["id"] == ATT,doc
assert not any(doc["capabilities"][p] for p in ("upload","delete","download"))
assert "storage_key" not in doc["results"][0]
assert "sha256" not in doc["results"][0]
print("ATT_HTTPS_AUTHORIZED_METADATA=PASS")
status, raw, _=request(PATH,"POST","{}",{"Content-Type":"application/json","Origin":BASE})
assert status == 403, (status,raw[:240])
# With valid TLS, origin and CSRF, the app must still deny uploads.
status,raw,_=request("/api/v1/csrf/")
assert status == 200,status
csrf=json.loads(raw)["csrfToken"]
mutate_headers={
    "Content-Type":"application/json",
    "Origin":BASE,
    "Referer":BASE + PATH,
    "X-CSRFToken":csrf,
}
status,raw,_=request(PATH,"POST","{}",mutate_headers)
assert status == 403,(status,raw[:240])
assert json.loads(raw)["detail"] == "Adjuntos no habilitados.",raw[:240]
status,raw,_=request(PATH+ATT+"/","GET")
assert status == 403,(status,raw[:240])
status,raw,_=request(PATH+ATT+"/","DELETE","{}",mutate_headers)
assert status == 403,(status,raw[:240])
print("ATT_HTTPS_CSRF_AND_FILE_OPERATIONS_FENCED=PASS")
# Verify the server's certificate name is not ignored even if CA is trusted.
wrong = ssl.create_default_context(cafile=CA)
try:
    wrong.wrap_socket(__import__("socket").create_connection(("attachment.test",8443),timeout=6),
                      server_hostname="not-attachment.test").do_handshake()
except (ssl.SSLError, OSError):
    print("ATT_HTTPS_HOSTNAME_MISMATCH_DENIED=PASS")
else:
    raise AssertionError("Hostname mismatch was accepted")
print("ATT_HTTPS_TRANSPORT_RESULT=PASS")
