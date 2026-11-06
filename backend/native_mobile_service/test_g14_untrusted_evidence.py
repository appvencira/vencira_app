"""G14-D2: negative proofs that D1 metadata is not an issuance grant.

Disposable database only. Document the time-of-check/time-of-use gap so that
future integration must not pass a D1 result into an issuer.
"""
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import Resolver404, resolve

from reminders.models import UserMfaState
from .g14_locked_verifier import verify_candidate_password_only
from .models import MobileDeviceSession
from .session_store import MobileTokenDenied, issue_verified_candidate_session
from .session_store import revoke_all_candidate_devices, validate_candidate_access


class G14UntrustedVerifierEvidenceTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="d2-disposable-only",
            password="d2-synthetic-only",
        )

    def evidence(self):
        return verify_candidate_password_only(
            username="d2-disposable-only", password="d2-synthetic-only",
        )

    def test_verified_metadata_becomes_stale_after_revocation(self):
        user_id, generation = self.evidence()
        self.assertEqual(user_id, self.user.pk)
        revoke_all_candidate_devices(user_id=self.user.pk)
        with self.assertRaises(MobileTokenDenied):
            issue_verified_candidate_session(
                user_id=user_id, verified_mfa=False, mfa_epoch=None,
                expected_generation=generation,
            )
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_verified_metadata_does_not_survive_password_rotation(self):
        user_id, generation = self.evidence()
        self.user.set_password("d2-new-password")
        self.user.save(update_fields=["password"])
        # This test records the current candidate risk: the low-level issuer
        # only receives a claimed MFA state, not a proof of fresh password.
        # Consequently even a successful low-level issuance must never be
        # taken as evidence that the original D1 verification is still valid.
        access, _ = issue_verified_candidate_session(
            user_id=user_id, verified_mfa=False, mfa_epoch=None,
            expected_generation=generation,
        )
        self.assertEqual(validate_candidate_access(access).pk, self.user.pk)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    def test_mfa_enabled_after_password_check_denies_non_mfa_issuer(self):
        user_id, generation = self.evidence()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=10,
            encrypted_totp_secret="not-a-real-secret",
        )
        with self.assertRaises(MobileTokenDenied):
            issue_verified_candidate_session(
                user_id=user_id, verified_mfa=False, mfa_epoch=None,
                expected_generation=generation,
            )
        self.assertFalse(MobileDeviceSession.objects.exists())

    @override_settings(ROOT_URLCONF="config.urls")
    def test_no_native_issuer_routes_in_operational_urls(self):
        from django.urls import clear_url_caches
        try:
            clear_url_caches()
            for path in (
                "/api/v1/mobile/auth/password/",
                "/api/v1/mobile/auth/mfa/",
                "/api/v1/mobile/auth/refresh/",
            ):
                with self.subTest(path=path):
                    with self.assertRaises(Resolver404):
                        resolve(path)
        finally:
            clear_url_caches()
