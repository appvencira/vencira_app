"""G14-D3 candidate-only composition, using disposable Django databases."""
import uuid
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from reminders.models import UserMfaState
from .g14_d3_candidate_boundary import candidate_non_mfa_flow
from .models import MobileAuthAuditEvent, MobileAuthAttemptBucket, MobileDeviceSession
from .session_store import validate_candidate_access
from .session_store import MobileTokenDenied


@override_settings(
    VENCIRA_G5_ABUSE_KEY="synthetic-g14-d3-abuse-key-isolation-only",
    VENCIRA_G5_AUDIT_KEY="synthetic-g14-d3-audit-key-isolation-only",
)
class G14D3CandidateBoundaryTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="g14d3-user", password="synthetic-g14d3-pass",
        )

    def attempt(self, *, username="g14d3-user", password="synthetic-g14d3-pass",
                event_id=None):
        return candidate_non_mfa_flow(
            username=username, password=password,
            request_meta={"REMOTE_ADDR": "198.51.100.12"},
            event_id=event_id or uuid.uuid4(),
        )

    def test_verified_non_mfa_account_commits_session_and_success_audit(self):
        pair = self.attempt()
        self.assertEqual(len(pair), 2)
        self.assertEqual(validate_candidate_access(pair[0]).pk, self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(
            list(MobileAuthAuditEvent.objects.values_list("event_type", flat=True)),
            ["auth_verified"],
        )

    def test_wrong_password_commits_denial_and_budget_but_no_session(self):
        self.assertIsNone(self.attempt(password="incorrect"))
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAttemptBucket.objects.count(), 2)
        self.assertEqual(
            MobileAuthAuditEvent.objects.get().event_type, "auth_denied",
        )

    def test_unknown_account_has_same_denied_event(self):
        self.assertIsNone(self.attempt(username="absent-user"))
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(
            MobileAuthAuditEvent.objects.get().event_type, "auth_denied",
        )

    def test_enabled_mfa_denies_password_only(self):
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=12,
            encrypted_totp_secret="synthetic-not-decryptable",
        )
        self.assertIsNone(self.attempt())
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.get().event_type, "auth_denied")

    def test_audit_key_absence_denies_before_any_budget_or_session(self):
        with override_settings(VENCIRA_G5_AUDIT_KEY=None):
            with self.assertRaises(Exception):
                self.attempt()
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(MobileAuthAttemptBucket.objects.exists())

    def test_conflicting_success_audit_rolls_back_new_session(self):
        event = uuid.uuid4()
        self.assertIsNone(self.attempt(password="incorrect", event_id=event))
        with self.assertRaises(Exception):
            self.attempt(event_id=event)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertEqual(MobileAuthAuditEvent.objects.count(), 1)

    def test_password_rotation_rejects_old_secret(self):
        self.user.set_password("synthetic-g14d3-new-password")
        self.user.save(update_fields=["password"])
        self.assertIsNone(self.attempt())
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_missing_audit_cannot_leave_valid_access(self):
        with override_settings(VENCIRA_G5_AUDIT_KEY=None):
            with self.assertRaises(Exception):
                self.attempt()
        self.assertFalse(MobileDeviceSession.objects.exists())
