"""G7-D2 isolated, single-use Django TLS fixture for a Flutter/Dart client.

This process must NEVER be started outside a Docker --internal network with
no published ports and disposable tmpfs SQLite. It explicitly refuses
anything except VENCIRA_ENV=test, VENCIRA_NATIVE_SESSION_LAB=1 and SQLite.

The operational Django URLconf is NOT changed. A temporary certificate is
signed by a disposable lab CA; only the public CA is exported to the client.
"""
import os
import shutil
import ssl
import tempfile
import threading
from http.server import ThreadingHTTPServer
from pathlib import Path
from wsgiref.simple_server import make_server

if (
    os.environ.get("VENCIRA_ENV") != "test"
    or os.environ.get("VENCIRA_NATIVE_SESSION_LAB") != "1"
    or os.environ.get("VENCIRA_DB_ENGINE") != "sqlite"
    or os.environ.get("G7_D2_ISOLATED_NETWORK_ACK") != "1"
):
    raise SystemExit("G7_D2_FIXTURE=DENIED: test-only isolated SQLite required")

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django  # noqa: E402
from django.conf import settings  # noqa: E402
from django.core.management import call_command  # noqa: E402
from django.urls import clear_url_caches  # noqa: E402
from django.core.wsgi import get_wsgi_application  # noqa: E402

from native_sessions_lab.test_verified_https_loopback import (  # noqa: E402
    _LoopbackTlsRelay, _create_ephemeral_certificates,
)


def run():
    django.setup()
    if (
        settings.VENCIRA_ENV != "test"
        or not settings.VENCIRA_NATIVE_SESSION_LAB
        or "native_sessions_lab" not in settings.INSTALLED_APPS
        or settings.DATABASES["default"]["ENGINE"]
        != "django.db.backends.sqlite3"
    ):
        raise SystemExit("G7_D2_FIXTURE=DENIED: unsafe settings")

    # The only writable database lives in Docker tmpfs, not on the host or
    # image filesystem. Never pass PostgreSQL credentials to this fixture.
    settings.DATABASES["default"]["NAME"] = "/tmp/g7d2-disposable.sqlite3"
    settings.ROOT_URLCONF = "native_sessions_lab.test_urls"
    clear_url_caches()

    call_command("migrate", interactive=False, verbosity=0)
    from django.contrib.auth import get_user_model
    user = get_user_model()
    user.objects.create_user(
        username="g7-d2-synthetic",
        password="G7-D2-Only-Synthetic-Password-2026!",
    )

    # G7-E: a separate synthetic MFA account; the RFC 6238 sample key is
    # deliberately public test material, NEVER an operational account key.
    # The Fernet encryption key is newly generated each run and remains
    # inside the disposable backend process (not in Docker environment args,
    # Git, logs, host mounts or client containers).
    from cryptography.fernet import Fernet
    from reminders.mfa_secrets import encrypt_totp_secret
    from reminders.models import UserMfaState

    mfa_key = Fernet.generate_key().decode("ascii")
    os.environ["VENCIRA_MFA_FERNET_KEYS"] = mfa_key
    os.environ["VENCIRA_MFA_FERNET_KEYS_FILE"] = ""
    mfa_user = user.objects.create_user(
        username="g7-e-mfa-synthetic",
        password="G7-E-Only-Synthetic-Mfa-Password-2026!",
    )
    UserMfaState.objects.create(
        user=mfa_user,
        enabled=True,
        session_epoch=1,
        encrypted_totp_secret=encrypt_totp_secret(
            "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            user_id=mfa_user.pk,
            keys=[mfa_key],
        ),
    )

    # G7-G test-only MFA recovery identity. Separate account means its
    # counter is not consumed by G7-E in the same all-in-one fixture.
    # Same PUBLIC RFC TOTP vector; Fernet key remains ephemeral and private.
    recovery_mfa_user = user.objects.create_user(
        username="g7-g-mfa-recovery",
        password="G7-G-Only-Synthetic-Mfa-Password-2026!",
    )
    UserMfaState.objects.create(
        user=recovery_mfa_user,
        enabled=True,
        session_epoch=1,
        encrypted_totp_secret=encrypt_totp_secret(
            "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            user_id=recovery_mfa_user.pk,
            keys=[mfa_key],
        ),
    )

    application = get_wsgi_application()
    django_server = make_server("127.0.0.1", 0, application)
    upstream_port = django_server.server_port
    threading.Thread(
        target=django_server.serve_forever, daemon=True,
    ).start()

    with tempfile.TemporaryDirectory(prefix="vencira-g7d2-") as tmp:
        ca, cert, key = _create_ephemeral_certificates(Path(tmp))
        tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls_context.minimum_version = ssl.TLSVersion.TLSv1_2
        tls_context.load_cert_chain(str(cert), str(key))

        # 0.0.0.0 is reachable ONLY from peer containers on the private
        # Docker --internal bridge. No port is published on host.
        relay = ThreadingHTTPServer(
            ("0.0.0.0", 8443), _LoopbackTlsRelay,
        )
        relay.upstream_port = upstream_port
        relay.daemon_threads = True
        relay.socket = tls_context.wrap_socket(
            relay.socket, server_side=True,
        )
        try:
            shutil.copyfile(ca, "/tmp/g7d2-public-ca.pem")
            Path("/tmp/g7d2-ready").touch()
            print("G7_D2_FIXTURE_READY=OK", flush=True)
            relay.serve_forever(poll_interval=0.05)
        finally:
            relay.server_close()
            django_server.shutdown()
            django_server.server_close()


if __name__ == "__main__":
    run()
