#!/usr/bin/env python3
"""D1-X: inspect the *loaded* local Caddy API config, without printing its content.

Does not read application secrets, run reloads or send any mutations.
An unavailable/disabled admin API is UNVERIFIED, never PASS.
"""
import json
import sys
import urllib.error
import urllib.request

PREFIX = "D1X_CADDY"


def mark(k, v):
    print(f"{PREFIX}_{k}={v}", flush=True)


def walk(value, handlers, depths=0):
    if depths > 60:
        raise ValueError("excessive config nesting")
    if isinstance(value, dict):
        handler = value.get("handler")
        if isinstance(handler, str):
            handlers.add(handler)
        for key, item in value.items():
            if key not in ("environment", "env", "password"):
                walk(item, handlers, depths + 1)
    elif isinstance(value, list):
        for item in value:
            walk(item, handlers, depths + 1)


def main():
    mark("READ_ONLY", "YES")
    mark("CONFIG_PRINTED", "NO")
    mark("DEV_MUTATIONS", "NO")
    request = urllib.request.Request(
        "http://127.0.0.1:2019/config/",
        method="GET",
        headers={"Accept": "application/json"},
    )
    # No proxies; no external hosts or user-provided URL.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=4) as response:
            if response.status != 200:
                raise RuntimeError("unexpected admin API response")
            raw = response.read(2_000_001)
    except (urllib.error.URLError, OSError, TimeoutError):
        mark("LOADED_CONFIG_VERIFIED", "NO")
        mark("ADMIN_API_AVAILABLE", "NO")
        mark("RESULT", 2)
        return 2
    if len(raw) > 2_000_000:
        mark("RESULT", 1)
        return 1
    try:
        payload = json.loads(raw)
        if not isinstance(payload, dict):
            raise ValueError("unexpected config schema")
        apps = payload.get("apps", {})
        http = apps.get("http") if isinstance(apps, dict) else None
        if not isinstance(http, dict) or not isinstance(http.get("servers"), dict):
            raise ValueError("no active HTTP server map")
        handlers = set()
        walk(http, handlers)
    except (ValueError, TypeError, RecursionError):
        mark("RESULT", 1)
        return 1
    mark("ADMIN_API_AVAILABLE", "YES")
    mark("LOADED_HTTP_SERVER_CONFIG", "PASS")
    mark("REVERSE_PROXY_PRESENT", "YES" if "reverse_proxy" in handlers else "NO")
    mark("STATIC_FILE_HANDLER_PRESENT", "YES" if "file_server" in handlers else "NO")
    # Presence of a reverse_proxy handler does not prove any site, domain,
    # upstream address, or the routing of dev.vencira.es in particular.
    mark("ROUTE_TO_DEV_HOST_VERIFIED", "NO")
    mark("FULL_OPERATIONAL_CONFIG_REVIEWED", "NO")
    mark("RESULT", 0 if "reverse_proxy" in handlers else 1)
    return 0 if "reverse_proxy" in handlers else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        mark("RESULT", 1)
        sys.exit(1)
