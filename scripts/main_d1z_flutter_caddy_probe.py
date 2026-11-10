"""D1-Z: external-client HTTPS probes against isolated Caddy/Gunicorn/PG17.

Only synthesized infrastructure; do not print response bodies or credentials.
"""
import argparse
import ssl
import urllib.error
import urllib.request


def request(url, context, *, method="GET", headers=None, data=None):
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=context),
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPRedirectHandler(),
    )
    req = urllib.request.Request(url, method=method, headers=headers or {}, data=data)
    try:
        with opener.open(req, timeout=7) as response:
            return response.status, response.headers
    except urllib.error.HTTPError as exc:
        return exc.code, exc.headers


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cert", required=True)
    args = parser.parse_args()
    host = "https://d1z-proxy"
    context = ssl.create_default_context(cafile=args.cert)
    routes = (
        ("/", 200),
        ("/main.dart.js", 200),
        ("/flutter_bootstrap.js", 200),
        ("/api/health/", 200),
        ("/api/ready/", 200),
        ("/accounts/login/", 200),
        ("/api/v1/csrf/", 200),
        ("/api/v1/me/", 403),
        ("/api/v1/native/issue/", 404),
    )
    for index, (path, expected) in enumerate(routes, 1):
        try:
            actual, headers = request(host + path, context)
        except (urllib.error.URLError, OSError, ssl.SSLError) as exc:
            print(f"D1Z_FAILED_ROUTE_INDEX={index}")
            print(f"D1Z_FAILED_EXCEPTION={type(exc).__name__}")
            raise
        if path == "/api/v1/me/" and actual in (401, 403):
            pass
        elif actual != expected:
            print(f"D1Z_FAILED_ROUTE_INDEX={index}")
            print(f"D1Z_FAILED_HTTP_STATUS={actual}")
            raise RuntimeError("unexpected HTTP response")
        if path == "/main.dart.js" and "javascript" not in headers.get("Content-Type", "").lower():
            print("D1Z_JAVASCRIPT_CONTENT_TYPE=FAIL")
            raise RuntimeError("incorrect JavaScript content type")
        if path == "/api/v1/csrf/":
            cookies = headers.get_all("Set-Cookie", [])
            if not any("Secure" in x and "vencira_csrftoken=" in x for x in cookies):
                print("D1Z_CSRF_COOKIE_FLAG=FAIL")
                raise RuntimeError("CSRF cookie must have secure flag")
    print("D1Z_FLUTTER_WEB_ROOT_AND_ASSETS=PASS")
    print("D1Z_CADDY_TLS_HTTP_CONTRACT=PASS")
    print("D1Z_CSRF_SECURE_COOKIE=PASS")
    code, _ = request(host + "/accounts/login/", context,
                      method="POST", headers={"Content-Type": "application/x-www-form-urlencoded"},
                      data=b"username=synthetic&password=invalid")
    if code != 403:
        print(f"D1Z_CSRF_POST_STATUS={code}")
        raise RuntimeError("CSRF POST unexpectedly admitted")
    print("D1Z_CSRF_POST_DENIED=PASS")
    try:
        request(host + "/api/health/", ssl.create_default_context())
    except urllib.error.URLError as exc:
        if not isinstance(exc.reason, ssl.SSLCertVerificationError):
            raise
    else:
        raise RuntimeError("untrusted CA unexpectedly accepted")
    print("D1Z_UNTRUSTED_CA_DENIED=PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("D1Z_PROXY_PROBE=FAIL")
        raise SystemExit(1)
