"""G5 candidate-only IP attribution. No production proxy trust is configured.

This module is an isolated policy primitive; it does NOT implement rate limiting.
Fail closed on malformed trusted-proxy metadata; never treat user-supplied
Forwarded/X-Forwarded-For as an authenticated IP without an exact proxy allowlist.
"""
from ipaddress import ip_address


class UntrustedNetworkIdentity(ValueError):
    """Network attribution is ambiguous; reject an authentication attempt."""


def _address(value):
    if not isinstance(value, str) or not value or value != value.strip():
        raise UntrustedNetworkIdentity()
    try:
        address = ip_address(value)
    except ValueError as exc:
        raise UntrustedNetworkIdentity() from exc
    # IPv4 mapped IPv6 has only one canonical representation for comparison.
    return address.ipv4_mapped if getattr(address, "ipv4_mapped", None) else address


def candidate_client_ip(meta, *, trusted_proxy_ips=()):
    """Return canonical single-hop client IP or fail closed.

    Proxy addresses must be configured by an operator from network topology,
    never inferred from request headers or broad private-address CIDRs.
    Untrusted peers are treated as direct clients and cannot override REMOTE_ADDR.
    Trusted peers must provide exactly one X-Forwarded-For address; chains and
    RFC 7239 Forwarded are rejected until the proxy topology is reviewed.
    """
    if not isinstance(meta, dict):
        raise UntrustedNetworkIdentity()
    peer = _address(meta.get("REMOTE_ADDR"))
    trusted = {_address(item) for item in trusted_proxy_ips}
    if peer not in trusted:
        return str(peer)
    forwarded = meta.get("HTTP_X_FORWARDED_FOR")
    if not isinstance(forwarded, str) or "," in forwarded:
        raise UntrustedNetworkIdentity()
    if meta.get("HTTP_FORWARDED") is not None:
        raise UntrustedNetworkIdentity()
    client = _address(forwarded)
    if client == peer:
        raise UntrustedNetworkIdentity()
    return str(client)
