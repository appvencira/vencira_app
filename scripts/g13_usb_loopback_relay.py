#!/usr/bin/env python3
"""G13: stream-only localhost ADB proxy to one disposable Docker TLS server.

NO HTTP parsing, credential logging, public listener, DNS, or operational URL.
Host binds 127.0.0.1 ONLY; the backend is a checked RFC1918 Docker address.
Caller is responsible for Docker --internal and cleanup.
"""
import ipaddress
import os
import selectors
import socket
import socketserver
import sys

LAB_PORT = 18743
SERVER_PORT = 8443


def _private_docker_peer(argument):
    ip = ipaddress.ip_address(argument)
    if not isinstance(ip, ipaddress.IPv4Address) or not ip.is_private:
        raise SystemExit("G13_PROXY_PEER_NOT_PRIVATE")
    if ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_unspecified:
        raise SystemExit("G13_PROXY_PEER_NOT_DOCKER")
    return str(ip)


class Forward(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            upstream = socket.create_connection(
                (self.server.private_peer, SERVER_PORT), timeout=5
            )
        except (OSError, TimeoutError):
            return
        with upstream:
            with selectors.DefaultSelector() as selector:
                self.request.setblocking(False)
                upstream.setblocking(False)
                selector.register(self.request, selectors.EVENT_READ, upstream)
                selector.register(upstream, selectors.EVENT_READ, self.request)
                while True:
                    try:
                        ready = selector.select(timeout=30)
                        if not ready:
                            return
                        for key, _ in ready:
                            data = key.fileobj.recv(65536)
                            if not data:
                                return
                            # TLS ciphertext only. Never inspect/log plaintext.
                            key.data.sendall(data)
                    except (OSError, ConnectionError):
                        return


class LoopbackServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = False
    daemon_threads = True


def main():
    if len(sys.argv) != 2 or os.getenv("G13_DISPOSABLE_ACK") != "1":
        raise SystemExit("G13_PROXY_REQUIRES_EXPLICIT_DISPOSABLE_LAB")
    peer = _private_docker_peer(sys.argv[1])
    with LoopbackServer(("127.0.0.1", LAB_PORT), Forward) as server:
        server.private_peer = peer
        print("G13_HOST_LOOPBACK_RELAY_READY=OK", flush=True)
        server.serve_forever(poll_interval=0.1)


if __name__ == "__main__":
    main()
