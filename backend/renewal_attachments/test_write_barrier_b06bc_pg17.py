"""B06B/C: pruebas con conexiones PostgreSQL independientes."""
import hashlib
import json
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

from django.core.exceptions import PermissionDenied
from django.db import connection, connections, close_old_connections
from django.test import TransactionTestCase, override_settings

from .offline_write_barrier_b06b import advisory_barrier
from .offline_capture_fence import verify_capture_fence


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B06BCPostgresTests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")

    def test_capture_blocks_cooperative_writer(self):
        entered = threading.Event()

        def writer():
            close_old_connections()
            try:
                with advisory_barrier(timeout=4):
                    entered.set()
                    return True
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(writer)
                self.assertFalse(entered.wait(0.25))

            self.assertTrue(future.result(timeout=6))
            self.assertTrue(entered.is_set())

    def test_writer_blocks_capture(self):
        entered = threading.Event()
        release = threading.Event()

        def writer():
            close_old_connections()
            try:
                with advisory_barrier(timeout=4):
                    entered.set()
                    if not release.wait(4):
                        raise RuntimeError("SYNTHETIC_TIMEOUT")
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(writer)
            try:
                self.assertTrue(entered.wait(3))
                with self.assertRaises(PermissionDenied):
                    with advisory_barrier(
                        capture=True, timeout=0.15
                    ):
                        self.fail("Capture unexpectedly acquired")
            finally:
                release.set()
            future.result(timeout=6)

        with advisory_barrier(capture=True, timeout=2):
            pass

    def test_error_releases_capture(self):
        with self.assertRaisesRegex(
            ValueError, "SYNTHETIC_CAPTURE_FAILURE"
        ):
            with advisory_barrier(capture=True):
                raise ValueError("SYNTHETIC_CAPTURE_FAILURE")

        with advisory_barrier(timeout=2):
            pass

    def test_production_denied(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                with advisory_barrier():
                    pass

    def test_invalid_timeout_denied(self):
        with self.assertRaises(PermissionDenied):
            with advisory_barrier(timeout=0):
                pass

    def test_capture_inventory_inside_barrier(self):
        # El inventario se lee de una tabla PG17 real.
        # No accede a PostgreSQL persistente.
        key = uuid.uuid4().hex
        cipher = b"B06C_SYNTHETIC_ENCRYPTED_BYTES"
        digest = hashlib.sha256(cipher).hexdigest()

        with connection.cursor() as cursor:
            cursor.execute(
                "CREATE TEMP TABLE b06c_inventory "
                "(storage_key text PRIMARY KEY, digest text)"
            )
            cursor.execute(
                "INSERT INTO b06c_inventory VALUES (%s,%s)",
                [key, digest],
            )

        with advisory_barrier(capture=True):
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT storage_key,digest "
                    "FROM b06c_inventory"
                )
                inventory = dict(cursor.fetchall())

            marker_digest = hashlib.sha256(
                json.dumps(
                    inventory, sort_keys=True,
                    separators=(",", ":")
                ).encode()
            ).hexdigest()

            marker = {
                "epoch": 1,
                "snapshot": "b06c-synthetic-pg17",
                "inventory_digest": marker_digest,
            }

            result = verify_capture_fence(
                before=marker,
                after=marker.copy(),
                database_inventory=inventory,
                object_inventory={key: digest},
            )

        self.assertTrue(result["consistent"])
        self.assertFalse(result["release_authorized"])
