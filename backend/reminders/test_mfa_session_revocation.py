"""Pruebas del epoch de sesiones MFA con datos sintéticos."""
from django.contrib.auth import get_user_model
from django.test import TestCase, RequestFactory
from django.contrib.sessions.middleware import SessionMiddleware

from .mfa_middleware import RequireMfaSessionMiddleware, SESSION_VERIFIED, SESSION_EPOCH
from .mfa_session_revocation import revoke_mfa_sessions
from .models import UserMfaState, MfaAdministrativeRecoveryCase
from django.utils import timezone
from datetime import timedelta


class MfaSessionRevocationTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="epoch_subject", password="synthetic-test-password-2026!"
        )
        self.state = UserMfaState.objects.create(
            user=self.user, enabled=True, encrypted_totp_secret="synthetic"
        )

    def test_epoch_revoke_and_middleware_logout(self):
        req = RequestFactory().get("/api/v1/me/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.session[SESSION_VERIFIED] = self.user.get_session_auth_hash()
        req.session[SESSION_EPOCH] = 0
        req.user = self.user
        self.assertEqual(
            RequireMfaSessionMiddleware(lambda r: None)(req), None
        )
        self.assertEqual(revoke_mfa_sessions(user_id=self.user.pk),
                         (True, "MFA_SESSIONS_REVOKED"))
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 1)
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)
        self.assertEqual(denied["Cache-Control"], "no-store")
        self.state.refresh_from_db()
        self.assertTrue(self.state.enabled)

    def test_disabled_account_cannot_increment_epoch(self):
        self.state.enabled = False
        self.state.save(update_fields=["enabled"])
        self.assertEqual(revoke_mfa_sessions(user_id=self.user.pk),
                         (False, "MFA_NOT_ENABLED"))
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 0)

    def test_missing_epoch_is_denied_even_if_login_hash_matches(self):
        req = RequestFactory().get("/admin/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.session[SESSION_VERIFIED] = self.user.get_session_auth_hash()
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)

    def test_revocation_twice_increments_epoch_and_keeps_factor(self):
        self.assertEqual(revoke_mfa_sessions(user_id=self.user.pk)[0], True)
        self.assertEqual(revoke_mfa_sessions(user_id=self.user.pk)[0], True)
        self.state.refresh_from_db()
        self.assertEqual(self.state.session_epoch, 2)
        self.assertTrue(self.state.enabled)

    def test_pending_administrative_recovery_blocks_even_verified_session(self):
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        req = RequestFactory().get("/api/v1/me/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.session[SESSION_VERIFIED] = self.user.get_session_auth_hash()
        req.session[SESSION_EPOCH] = 0
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)
        self.assertEqual(denied["Cache-Control"], "no-store")

    def test_pending_administrative_recovery_blocks_even_if_enabled_false(self):
        self.state.enabled = False
        self.state.save(update_fields=["enabled"])
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now + timedelta(hours=24),
            expires_at=now + timedelta(hours=72),
        )
        req = RequestFactory().get("/admin/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)

    def test_expired_but_pending_case_still_blocks_until_explicit_resolution(self):
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            quarantine_until=now - timedelta(hours=40),
            expires_at=now - timedelta(hours=1),
        )
        req = RequestFactory().get("/api/v1/me/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.session[SESSION_VERIFIED] = self.user.get_session_auth_hash()
        req.session[SESSION_EPOCH] = 0
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)

    def test_closed_case_with_disabled_mfa_does_not_restore_password_only_access(self):
        self.state.enabled = False
        self.state.save(update_fields=["enabled"])
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            status=MfaAdministrativeRecoveryCase.Status.CLOSED,
            quarantine_until=now - timedelta(hours=25),
            expires_at=now + timedelta(hours=24),
        )
        req = RequestFactory().get("/api/v1/me/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)

    def test_cancelled_case_with_disabled_mfa_does_not_restore_access(self):
        self.state.enabled = False
        self.state.save(update_fields=["enabled"])
        now = timezone.now()
        MfaAdministrativeRecoveryCase.objects.create(
            subject=self.user, requester=self.user,
            status=MfaAdministrativeRecoveryCase.Status.CANCELLED,
            quarantine_until=now - timedelta(hours=25),
            expires_at=now + timedelta(hours=24),
        )
        req = RequestFactory().get("/admin/")
        SessionMiddleware(lambda r: None).process_request(req)
        req.user = self.user
        denied = RequireMfaSessionMiddleware(lambda r: None)(req)
        self.assertEqual(denied.status_code, 403)
