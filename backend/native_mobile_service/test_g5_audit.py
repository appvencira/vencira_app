"""G5 audit candidate tests; synthetic actors, disposable DB only."""
import uuid
from datetime import timedelta

from django.test import TestCase, override_settings
from django.utils import timezone

from .g5_audit import (
    MobileAuditDenied, purge_candidate_auth_events,
    record_candidate_auth_event,
)
from .models import MobileAuthAuditEvent


@override_settings(VENCIRA_G5_AUDIT_KEY="g5-audit-only-synthetic-key-material-2026-not-production")
class G5AuditContractTests(TestCase):
    def test_idempotent_redacted_event(self):
        eid = uuid.uuid4()
        first, created = record_candidate_auth_event(
            event_id=eid, event_type="auth_denied",
            actor="synthetic@example.invalid",
        )
        self.assertTrue(created)
        second, created = record_candidate_auth_event(
            event_id=eid, event_type="auth_denied",
            actor="synthetic@example.invalid",
        )
        self.assertFalse(created)
        self.assertEqual(first.pk, second.pk)
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)
        self.assertEqual(len(first.actor_digest), 64)
        self.assertNotIn("synthetic", first.actor_digest)

    def test_reuse_id_with_different_payload_fails(self):
        eid = uuid.uuid4()
        record_candidate_auth_event(event_id=eid, event_type="device_logout")
        with self.assertRaises(MobileAuditDenied):
            record_candidate_auth_event(event_id=eid, event_type="account_revoke")

    def test_only_allowlisted_events(self):
        with self.assertRaises(MobileAuditDenied):
            record_candidate_auth_event(
                event_id=uuid.uuid4(), event_type="leak_token",
            )

    def test_missing_key_fails_closed(self):
        with override_settings(VENCIRA_G5_AUDIT_KEY=None):
            with self.assertRaises(MobileAuditDenied):
                record_candidate_auth_event(
                    event_id=uuid.uuid4(), event_type="auth_denied",
                )

    def test_invalid_actor_rejected(self):
        for actor in ("", " leading", "trailing ", "a" * 255):
            with self.subTest(actor=actor):
                with self.assertRaises(MobileAuditDenied):
                    record_candidate_auth_event(
                        event_id=uuid.uuid4(), event_type="auth_denied",
                        actor=actor,
                    )

    def test_purge_old_only(self):
        old_id = uuid.uuid4()
        new_id = uuid.uuid4()
        record_candidate_auth_event(event_id=old_id, event_type="auth_denied")
        record_candidate_auth_event(event_id=new_id, event_type="refresh_rotated")
        MobileAuthAuditEvent.objects.filter(pk=old_id).update(
            occurred_at=timezone.now() - timedelta(days=31),
        )
        self.assertEqual(purge_candidate_auth_events(), 1)
        self.assertFalse(MobileAuthAuditEvent.objects.filter(pk=old_id).exists())
        self.assertTrue(MobileAuthAuditEvent.objects.filter(pk=new_id).exists())

    def test_cannot_purge_more_recent_records(self):
        with self.assertRaises(MobileAuditDenied):
            purge_candidate_auth_events(before=timezone.now())

    def test_test_only_gate(self):
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            with self.assertRaises(MobileAuditDenied):
                record_candidate_auth_event(
                    event_id=uuid.uuid4(), event_type="auth_denied",
                )
