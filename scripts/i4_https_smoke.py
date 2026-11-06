#!/usr/bin/env python3
"""I4 HTTPS wire-level smoke: real Django + disposable PG17 + built Flutter assets."""
import argparse
import http.cookiejar
import json
import os
import ssl
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import HTTPCookieProcessor, HTTPSHandler, Request, build_opener

BASE = "https://localhost:18732"


def check(ok, label):
    if not ok:
        raise AssertionError("I4_FAILED_" + label)
    print("I4_" + label + "=OK", flush=True)


class Browser:
    def __init__(self, ca):
        self.cookies = http.cookiejar.CookieJar()
        context = ssl.create_default_context(cafile=ca)
        context.check_hostname = True
        self.opener = build_opener(HTTPCookieProcessor(self.cookies), HTTPSHandler(context=context))

    def request(self, path, *, form=None, token=None):
        data = None if form is None else urlencode(form).encode("utf-8")
        headers = {"Accept": "application/json,text/html"}
        if data is not None:
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            headers["Origin"] = BASE
            headers["Referer"] = BASE + "/accounts/login/"
        if token:
            headers["X-CSRFToken"] = token
        req = Request(BASE + path, data=data, headers=headers)
        try:
            with self.opener.open(req, timeout=8) as res:
                return res.status, res.read(), dict(res.headers)
        except HTTPError as err:
            return err.code, err.read(), dict(err.headers)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ca", required=True)
    parser.add_argument("--fixture", type=Path, default=Path("/tmp/vencira-i4-fixture.json"))
    args = parser.parse_args()
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    owner = Browser(args.ca)

    # A real HTTPS handshake, with trust and hostname validation, to the built site.
    for _ in range(45):
        try:
            code, body, _ = owner.request("/api/health/")
            if code == 200:
                break
        except (OSError, URLError):
            time.sleep(1)
    else:
        raise AssertionError("I4_HTTPS_SERVER_NOT_READY")

    check(code == 200 and json.loads(body)["status"] == "ok", "HEALTH")
    code, body, _ = owner.request("/api/ready/")
    check(code == 200 and json.loads(body)["status"] == "ready", "PG_READY")
    code, body, headers = owner.request("/")
    check(code == 200 and b"VENCIRA" in body and "text/html" in headers.get("Content-Type", ""), "FLUTTER_WEB_INDEX")
    code, body, _ = owner.request("/flutter_bootstrap.js")
    check(code == 200 and len(body) > 100, "FLUTTER_BOOTSTRAP")

    code, body, _ = owner.request("/api/v1/me/")
    check(code in (401, 403), "ANONYMOUS_DENIED")
    code, body, _ = owner.request("/accounts/login/")
    check(code == 200 and b"csrfmiddlewaretoken" in body, "LOGIN_FORM")
    code, body, _ = owner.request("/api/v1/csrf/")
    check(code == 200 and "csrfToken" in json.loads(body), "CSRF_BOOTSTRAP")
    token = json.loads(body)["csrfToken"]
    check(any(c.name == "vencira_csrftoken" and c.secure for c in owner.cookies), "CSRF_SECURE_COOKIE")

    code, body, _ = owner.request("/accounts/login/", form={
        "username": "i4-owner",
        "password": os.environ["I4_OWNER_PASSWORD"],
        "csrfmiddlewaretoken": token,
    })
    check(code == 200 and json.loads(body)["username"] == "i4-owner", "LOGIN_SESSION")
    check(any(c.name == "vencira_sessionid" and c.secure for c in owner.cookies), "SESSION_SECURE_COOKIE")

    code, body, _ = owner.request("/api/v1/workspaces/")
    ws = json.loads(body)
    check(code == 200 and len(ws) == 1 and str(ws[0]["id"]) == fixture["workspace"], "WORKSPACE_SCOPE")
    prefix = "/api/v1/workspaces/" + fixture["workspace"]
    code, body, _ = owner.request(prefix + "/renewals/")
    check(code == 200 and "I4-SYNTHETIC-ONLY" in body.decode("utf-8"), "RENEWALS")
    code, body, _ = owner.request(prefix + "/renewals/" + fixture["renewal"] + "/")
    check(code == 200, "RENEWAL_DETAIL")
    code, body, _ = owner.request(prefix + "/agenda/?day=2027-04-10")
    check(code == 200, "AGENDA_DAY")

    code, body, _ = owner.request("/api/v1/workspaces/" + fixture["foreign"] + "/renewals/")
    check(code == 404 and b"I4-SYNTHETIC-ONLY" not in body, "CROSS_TENANT_DENIED")
    attachment = prefix + "/renewals/" + fixture["renewal"] + "/attachments/"
    code, body, _ = owner.request(attachment)
    payload = json.loads(body) if code == 200 else {}
    check(code == 200 and payload["capabilities"] == {
        "upload": False, "download": False, "delete": False,
        "reason": "SECURITY_REVIEW_PENDING",
    }, "ATTACHMENTS_READ_ONLY")

    # New CSRF token after login (Django rotates CSRF secret on authentication).
    code, body, _ = owner.request("/api/v1/csrf/")
    token = json.loads(body)["csrfToken"]
    code, body, _ = owner.request(attachment, form={}, token=token)
    check(code == 403, "ATTACHMENT_UPLOAD_DENIED")
    code, body, _ = owner.request("/accounts/logout/", form={"csrfmiddlewaretoken": token})
    check(code == 200 and b"Acceso a tu agenda" in body, "LOGOUT_POST")
    code, body, _ = owner.request("/api/v1/me/")
    check(code in (401, 403), "LOGOUT_REVOKED")
    print("I4_HTTPS_PG17_FLUTTER_SMOKE=PASS", flush=True)
    print("I4_NO_PRODUCTION_NETWORK_OR_DB=1", flush=True)


if __name__ == "__main__":
    main()
