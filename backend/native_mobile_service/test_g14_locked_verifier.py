"""G14-D locked verifier is lab-only and never issues credentials."""
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings

from reminders.models import UserMfaState
from .g14_locked_verifier import (
    CandidateVerificationDenied, verify_candidate_password_only,
)
from .models import MobileDeviceSession
from .session_store import revoke_all_candidate_devices


class G14LockedPasswordVerifierTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="g14d-user",
            password="synthetic-g14d-password",
        )

    def verify(self, password="synthetic-g14d-password"):
        return verify_candidate_password_only(
            username="g14d-user", password=password,
        )

    def test_correct_password_returns_server_metadata_only(self):
        self.assertEqual(self.verify(), (self.user.pk, 0))
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_wrong_password_and_unknown_user_denied(self):
        with self.assertRaises(CandidateVerificationDenied):
            self.verify(password="incorrect")
        with self.assertRaises(CandidateVerificationDenied):
            verify_candidate_password_only(
                username="unregistered", password="incorrect",
            )
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_enabled_mfa_never_passes_password_only(self):
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=3,
            encrypted_totp_secret="test-only-unusable",
        )
        with self.assertRaises(CandidateVerificationDenied):
            self.verify()
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_password_rotation_invalidates_old_password(self):
        self.user.set_password("synthetic-g14d-new-password")
        self.user.save(update_fields=["password"])
        with self.assertRaises(CandidateVerificationDenied):
            self.verify()
        self.assertEqual(
            self.verify(password="synthetic-g14d-new-password"),
            (self.user.pk, 0),
        )

    def test_revocation_generation_is_read_from_server(self):
        revoke_all_candidate_devices(user_id=self.user.pk)
        self.assertEqual(self.verify(), (self.user.pk, 1))

    def test_inactive_user_denied(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        with self.assertRaises(CandidateVerificationDenied):
            self.verify()

    @override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False)
    def test_candidate_gate_closed(self):
        with self.assertRaises(CandidateVerificationDenied):
            self.verify()

    def test_malformed_username_rejected(self):
        for username in ("", " g14d-user", "g14d-user ", "x" * 151, None):
            with self.subTest(username=username):
                with self.assertRaises(CandidateVerificationDenied):
                    verify_candidate_password_only(
                        username=username, password="synthetic",
                    )
