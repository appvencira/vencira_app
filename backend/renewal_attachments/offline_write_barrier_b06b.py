"""B06B: bloqueo cooperativo PG17 para ensayos aislados.

NO es una barrera operacional: los escritores reales no
utilizan todavía este contrato.
"""
import time
from contextlib import contextmanager

from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db import connection

# Identificador fijo para que todos los participantes
# del MISMO PostgreSQL coordinen el mismo recurso.
LOCK_ID = 760620261029


def _guard():
    if (
        settings.VENCIRA_ENV != "test"
        or not getattr(
            settings,
            "VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED",
            False,
        )
        or connection.vendor != "postgresql"
        or connection.in_atomic_block
        or not connection.get_autocommit()
    ):
        raise PermissionDenied("B06B_ISOLATED_PG17_ONLY")


@contextmanager
def advisory_barrier(*, capture=False, timeout=5.0):
    """Exclusivo para captura; compartido para escritores.

    Ambos modos son bloqueos de sesión PostgreSQL.
    No bloqueará a escritores que ignoren el protocolo.
    """
    _guard()
    if (
        type(capture) is not bool
        or type(timeout) not in (float, int)
        or not 0 < timeout <= 30
    ):
        raise PermissionDenied("INVALID_BARRIER_ARGUMENTS")

    acquire = (
        "SELECT pg_try_advisory_lock(%s)"
        if capture
        else "SELECT pg_try_advisory_lock_shared(%s)"
    )
    release = (
        "SELECT pg_advisory_unlock(%s)"
        if capture
        else "SELECT pg_advisory_unlock_shared(%s)"
    )

    deadline = time.monotonic() + timeout
    obtained = False

    with connection.cursor() as cursor:
        while time.monotonic() < deadline:
            cursor.execute(acquire, [LOCK_ID])
            if cursor.fetchone()[0] is True:
                obtained = True
                break
            time.sleep(0.025)

        if not obtained:
            raise PermissionDenied("CAPTURE_BARRIER_TIMEOUT")

        try:
            yield
        finally:
            cursor.execute(release, [LOCK_ID])
            if cursor.fetchone()[0] is not True:
                raise RuntimeError("BARRIER_RELEASE_FAILURE")
