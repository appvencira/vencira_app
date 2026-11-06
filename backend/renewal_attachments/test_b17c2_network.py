import json
import os
import time
from datetime import timedelta
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from django.db import connection
from django.core.exceptions import PermissionDenied

from .test_b17_transport_receiver import B17TransportReceiverTests
from .offline_key_registry_b13d import TrustedPublicKey
from .offline_transport_receiver_b17 import receive_envelope_offline
from .offline_http_bridge_b17c import make_handler
from .models import AttachmentScanEvidence


class B17C2NetworkTests(B17TransportReceiverTests):

    def test_real_container_network(self):
        shared = Path("/exchange")
        public = bytes.fromhex(
            Path("/run/keys/public.hex").read_text().strip()
        )
        transport = Path("/run/keys/transport.key").read_bytes()

        assert len(public) == 32
        assert len(transport) == 32
        assert not Path("/run/keys/private.key").exists()

        registry = {
            "b17c2-synthetic": TrustedPublicKey(
                "b17c2-synthetic",
                public,
                self.now - timedelta(minutes=2),
                self.now + timedelta(minutes=10),
            )
        }


        # B17D: todas estas operaciones usan el receptor
        # real y la BD PostgreSQL 17 temporal.
        def policy_receive(registry, fail=False):
            return receive_envelope_offline(
                envelope={
                    "body": self.body,
                    "mac": self.mac,
                },
                transport_key=self.transport_key,
                registry=registry,
                attachment_id=self.item.pk,
                expected_fingerprint=self.fingerprint,
                now=self.now,
                fail_after_evidence=fail,
            )

        own_key = self.registry["b15f-synthetic"]

        revoked = {
            "b15f-synthetic": TrustedPublicKey(
                own_key.key_id,
                own_key.public_key,
                own_key.valid_from,
                own_key.valid_until,
                revoked=True,
            )
        }

        expired = {
            "b15f-synthetic": TrustedPublicKey(
                own_key.key_id,
                own_key.public_key,
                self.now - timedelta(minutes=20),
                self.now - timedelta(minutes=1),
            )
        }

        not_yet_valid = {
            "b15f-synthetic": TrustedPublicKey(
                own_key.key_id,
                own_key.public_key,
                self.now + timedelta(minutes=1),
                self.now + timedelta(minutes=20),
            )
        }

        for label, candidate in (
            ("REVOKED", revoked),
            ("EXPIRED", expired),
            ("NOT_YET_VALID", not_yet_valid),
            ("UNKNOWN", {}),
        ):
            with self.assertRaises(PermissionDenied):
                policy_receive(candidate)

            self.assertEqual(
                AttachmentScanEvidence.objects.count(), 0
            )
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT count(*) FROM b17_replay"
                )
                self.assertEqual(cursor.fetchone()[0], 0)

            print(
                f"B17D_{label}_KEY_REJECTED=OK",
                flush=True,
            )

        with self.assertRaises(RuntimeError):
            policy_receive(self.registry, fail=True)

        self.assertEqual(
            AttachmentScanEvidence.objects.count(), 0
        )
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT count(*) FROM b17_replay"
            )
            self.assertEqual(cursor.fetchone()[0], 0)

        print("B17D_ATOMIC_ROLLBACK=OK", flush=True)

        case = self

        def receive(envelope):
            # Cada petición HTTP usa un hilo independiente.
            # No conservar conexiones a la BD de test tras responder.
            connection.close()
            try:
                return receive_envelope_offline(
                    envelope=envelope,
                    transport_key=transport,
                    registry=registry,
                    attachment_id=case.item.pk,
                    expected_fingerprint=case.fingerprint,
                    now=case.now,
                )
            finally:
                connection.close()

        server = ThreadingHTTPServer(
            ("0.0.0.0", 8080),
            make_handler(receive),
        )
        thread = Thread(
            target=server.serve_forever,
            daemon=True,
        )
        thread.start()

        try:
            fixture = {
                "storage_key": str(self.item.storage_key),
                "sha256": self.item.sha256,
                "key_id": "b17c2-synthetic",
                "timestamp": int(self.now.timestamp()),
            }

            fixture_path = shared / "fixture.json"
            fixture_path.write_text(json.dumps(fixture))
            fixture_path.chmod(0o644)
            print("B17C2_FIXTURE_READY=OK", flush=True)

            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                if (shared / "client.done").exists():
                    break
                time.sleep(0.2)
            else:
                self.fail("B17C2_CLIENT_TIMEOUT")

            self.assertEqual(
                AttachmentScanEvidence.objects.count(), 1
            )

            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT count(*) FROM b17_replay"
                )
                self.assertEqual(cursor.fetchone()[0], 1)

            self.item.refresh_from_db()
            self.assertEqual(self.item.state, "quarantined")

            print("B17C2_ATOMIC_EVIDENCE=OK", flush=True)
            print("B17C2_NONCE_PERSISTED=OK", flush=True)
            print("B17C2_QUARANTINE_PRESERVED=OK", flush=True)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)
