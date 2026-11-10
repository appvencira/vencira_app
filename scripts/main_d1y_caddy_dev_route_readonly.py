#!/usr/bin/env python3
"""D1-Y: classify routes for dev.vencira.es in Caddy's loaded HTTP config.

Read-only GET to loopback API; no raw config, host paths or upstream addresses
are emitted. A syntactically matched host and scoped proxy are not proof that
a backend is reachable, so the gate remains limited to loaded route structure.
"""
import json
import sys
import urllib.error
import urllib.request

HOST = "dev.vencira.es"
MAX_BYTES = 2_000_000


def mark(name, status):
    print(f"D1Y_CADDY_{name}={status}", flush=True)


def proxy_in_handlers(handlers, depth=0):
    if depth > 40 or not isinstance(handlers, list):
        return False
    for handler in handlers:
        if not isinstance(handler, dict):
            continue
        if handler.get("handler") == "reverse_proxy":
            return True
        # A subroute's matchers must be evaluated by visit_routes().
        # Traversing nested routes here would misattribute unrelated hosts.
        if proxy_in_handlers(handler.get("handlers"), depth + 1):
            return True
    return False


def visit_routes(routes, *, inherited_host=False, depth=0):
    if depth > 40 or not isinstance(routes, list):
        raise ValueError("invalid routes")
    seen_host, seen_proxy = False, False
    for route in routes:
        if not isinstance(route, dict):
            raise ValueError("invalid route")
        match = route.get("match", [])
        if not isinstance(match, list):
            raise ValueError("invalid matcher")
        explicit_hosts = []
        for criterion in match:
            if not isinstance(criterion, dict):
                raise ValueError("invalid host matcher")
            hosts = criterion.get("host", [])
            if not isinstance(hosts, list):
                raise ValueError("invalid hosts")
            explicit_hosts.extend(hosts)
        host_scope = (inherited_host or HOST in explicit_hosts) and ( 
            not explicit_hosts or HOST in explicit_hosts
        )
        if host_scope:
            seen_host = True
        if host_scope and proxy_in_handlers(route.get("handle", [])):
            seen_proxy = True
        for handler in route.get("handle", []):
            if not isinstance(handler, dict):
                continue
            if handler.get("handler") == "subroute":
                nested_host, nested_proxy = visit_routes(
                    handler.get("routes", []), inherited_host=host_scope,
                    depth=depth + 1)
                seen_host |= nested_host
                seen_proxy |= nested_proxy
    return seen_host, seen_proxy


def main():
    mark("READ_ONLY", "YES")
    mark("CONFIG_CONTENT_PRINTED", "NO")
    mark("MUTATIONS_EXECUTED", "NO")
    req = urllib.request.Request("http://127.0.0.1:2019/config/",
                                 method="GET", headers={"Accept": "application/json"})
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=5) as response:
            if response.status != 200:
                raise ValueError("invalid response status")
            raw = response.read(MAX_BYTES + 1)
    except (urllib.error.URLError, OSError, TimeoutError):
        mark("LOADED_CONFIG_AVAILABLE", "NO")
        mark("RESULT", 2)
        return 2
    if len(raw) > MAX_BYTES:
        mark("RESULT", 1)
        return 1
    try:
        config = json.loads(raw)
        servers = config["apps"]["http"]["servers"]
        if not isinstance(servers, dict) or not servers:
            raise ValueError("HTTP server missing")
        hosts, proxies = [], []
        for server in servers.values():
            h, p = visit_routes(server.get("routes", []))
            hosts.append(h)
            proxies.append(p)
    except (ValueError, KeyError, TypeError, RecursionError):
        mark("RESULT", 1)
        return 1
    mark("LOADED_CONFIG_AVAILABLE", "YES")
    mark("DEV_HOST_MATCH_PRESENT", "YES" if any(hosts) else "NO")
    mark("DEV_HOST_SCOPED_PROXY_PRESENT", "YES" if any(proxies) else "NO")
    mark("DEV_UPSTREAM_REACHABILITY_VERIFIED", "NO")
    mark("TLS_HOST_CERTIFICATE_VERIFIED", "NO")
    mark("BROWSER_VISUAL_VERIFIED", "NO")
    result = 0 if any(proxies) else 2
    mark("RESULT", result)
    return result


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        mark("RESULT", 1)
        sys.exit(1)
