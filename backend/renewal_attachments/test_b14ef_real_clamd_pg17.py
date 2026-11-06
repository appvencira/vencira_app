import hashlib
import os
import tempfile
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace

from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.asymmetric.ed25519 import (
    Ed25519PrivateKey,
)
from django.core.exceptions import PermissionDenied
from django.test import TransactionTestCase, override_settings

from reminders.models import Workspace, Renewal
from reminders.attachment_private_store import PrivateQuarantineStore
from reminders.attachment_clamav_adapter import scan_with_clamd
from reminders.attachment_gate import may_download_attachment
from b14_isolation_rehearsal.scan_sign_contract import scan_and_sign_v3
from .models import RenewalAttachment, AttachmentScanEvidence
from .offline_ed25519_b13b import public_key_bytes
from .offline_key_registry_b13d import TrustedPublicKey
from .offline_keyed_v3_b13e import persist_keyed_v3_offline


@override_settings(
    VENCIRA_ENV="test",
    VENCIRA_ATTACHMENT_SPLIT_REHEARSAL_ENABLED=True,
)
class B14EFRealClamdPG17(TransactionTestCase):
    def setUp(self):
        self.socket = os.environ["VENCIRA_B14_CLAMD_SOCKET"]
        self.now = datetime.now(timezone.utc)
        self.private = Ed25519PrivateKey.generate()
        self.content = b"%PDF-1.7\nstartxref\n1\n%%EOF"

        self.temp = tempfile.TemporaryDirectory(prefix="b14ef-")
        self.addCleanup(self.temp.cleanup)
        os.chmod(self.temp.name, 0o700)
        self.store = PrivateQuarantineStore(
            Path(self.temp.name), Fernet.generate_key()
        )

        ws = Workspace.objects.create(name="B14EF synthetic")
        renewal = Renewal.objects.create(
            workspace=ws,
            customer_reference="B14EF",
            full_name="Synthetic",
            expires_on=date(2027, 12, 1),
        )
        self.item = RenewalAttachment.objects.create(
            renewal=renewal,
            display_name="synthetic.pdf",
            content_type="application/pdf",
            byte_size=len(self.content),
            sha256=hashlib.sha256(self.content).hexdigest(),
            state="quarantined",
        )
        self.store.put_quarantine(
            self.item.storage_key, self.content
        )

    def fingerprint(self):
        return tuple(getattr(self.item, field) for field in (
            "storage_key", "sha256", "byte_size",
            "state", "display_name", "content_type"
        ))

    def scan(self, **kwargs):
        args = dict(
            store=self.store,
            attachment=self.item,
            socket_path=self.socket,
            private_key=self.private,
            key_id="b14ef-synthetic",
            engine="clamav-b14ef",
            now=self.now,
        )
        args.update(kwargs)
        return scan_and_sign_v3(**args)

    def test_real_clean_scan_signature_and_pg17(self):
        outcome = self.scan()
        self.assertEqual(outcome.verdict, "attested")
        self.assertFalse(outcome.release_allowed)

        registry = {
            "b14ef-synthetic": TrustedPublicKey(
                "b14ef-synthetic",
                public_key_bytes(self.private),
                self.now - timedelta(minutes=1),
                self.now + timedelta(minutes=10),
            )
        }
        saved = persist_keyed_v3_offline(
            attachment_id=self.item.pk,
            payload=outcome.payload,
            signature=outcome.signature,
            registry=registry,
            expected_fingerprint=self.fingerprint(),
            now=self.now,
        )
        self.assertEqual(saved.payload["key_id"], "b14ef-synthetic")
        self.assertEqual(len(saved.signature), 128)
        self.assertEqual(AttachmentScanEvidence.objects.count(), 1)
        self.item.refresh_from_db()
        self.assertEqual(self.item.state, "quarantined")
        self.assertFalse(may_download_attachment(
            attachment=self.item, membership=None
        ))
        with self.assertRaises(PermissionDenied):
            persist_keyed_v3_offline(
                attachment_id=self.item.pk,
                payload=outcome.payload,
                signature=outcome.signature,
                registry=registry,
                expected_fingerprint=self.fingerprint(),
                now=self.now,
            )

    def test_eicar_detected_by_real_clamd(self):
        eicar = (
            b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$"
            b"EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
        )
        result = scan_with_clamd(
            payload=eicar, unix_socket=self.socket,
            timeout_seconds=15,
        )
        self.assertEqual(result.verdict, "infected")

    def test_missing_socket_blocks_signature(self):
        result = self.scan(
            socket_path="/tmp/b14ef-no-socket.sock"
        )
        self.assertEqual(result.verdict, "blocked")
        self.assertIsNone(result.signature)

    def test_modified_sha_blocks_signature(self):
        self.item.sha256 = "0" * 64
        result = self.scan()
        self.assertEqual(result.verdict, "blocked")

    def test_production_blocks_scan_sign(self):
        with override_settings(VENCIRA_ENV="production"):
            result = self.scan()
        self.assertEqual(result.verdict, "blocked")

    def test_no_clamd_scan_with_wrong_lifecycle(self):
        self.item.state = "clean"
        result = self.scan()
        self.assertEqual(result.verdict, "blocked")
