"""B10A: evidencia firmada y concurrencia en PG17."""
import hashlib
import hmac
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
from threading import Event

from django.core.exceptions import PermissionDenied
from django.db import connection, connections, close_old_connections
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_scan_evidence import persist_scan_evidence_offline
from .offline_write_barrier_b06b import advisory_barrier


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B10AScanBarrierPG17Tests(TransactionTestCase):

    def setUp(self):
        self.assertEqual(connection.vendor, "postgresql")
        ws = Workspace.objects.create(
            name="B10A SYNTHETIC"
        )
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B10A",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=15,
            sha256=hashlib.sha256(
                b"synthetic bytes"
            ).hexdigest(),
            state=RenewalAttachment.State.QUARANTINED,
        )
        self.key = b"b10a-synthetic-attestation-" + b"x" * 32

    def evidence(self):
        now = datetime.now(timezone.utc)
        payload = {
            "object_key": str(self.item.storage_key),
            "sha256": self.item.sha256,
            "verdict": "clean",
            "scanned_at": int(now.timestamp()),
            "engine": "synthetic-test-engine",
        }
        raw = json.dumps(
            payload, sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")
        signature = hmac.new(
            self.key, raw, hashlib.sha256
        ).hexdigest()
        return payload, signature, now

    def persist(self, signature_override=None):
        payload, signature, now = self.evidence()
        return persist_scan_evidence_offline(
            attachment_id=self.item.pk,
            payload=payload,
            signature=(
                signature if signature_override is None
                else signature_override
            ),
            verification_key=self.key,
            now=now,
        )

    def test_evidence_remains_quarantined(self):
        self.persist()
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertEqual(
            AttachmentScanEvidence.objects.filter(
                attachment=self.item
            ).count(), 1
        )

    def test_invalid_signature_rejected(self):
        with self.assertRaises(PermissionDenied):
            self.persist(signature_override="0" * 64)

        self.assertFalse(
            AttachmentScanEvidence.objects.filter(
                attachment=self.item
            ).exists()
        )

    def test_duplicate_evidence_rejected(self):
        self.persist()
        with self.assertRaises(PermissionDenied):
            self.persist()

    def test_capture_blocks_evidence_writer(self):
        started = Event()
        completed = Event()

        def worker():
            close_old_connections()
            try:
                started.set()
                result = self.persist()
                completed.set()
                return result.pk
            finally:
                connections.close_all()

        with ThreadPoolExecutor(max_workers=1) as pool:
            with advisory_barrier(capture=True, timeout=4):
                future = pool.submit(worker)
                self.assertTrue(started.wait(2))
                self.assertFalse(completed.wait(0.25))
                self.assertFalse(future.done())

            self.assertIsNotNone(
                future.result(timeout=7)
            )

        self.assertTrue(completed.is_set())

    def test_production_rejected(self):
        with override_settings(VENCIRA_ENV="production"):
            with self.assertRaises(PermissionDenied):
                self.persist()

    def test_no_evidence_on_rejected_item(self):
        self.item.state = RenewalAttachment.State.REJECTED
        self.item.save(update_fields=["state"])
        with self.assertRaises(PermissionDenied):
            self.persist()
