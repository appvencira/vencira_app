"""Pruebas del epoch de sesiones MFA con datos sintéticos."""
from django.contrib.auth import get_user_model
from django.test import TestCase, RequestFactory
from django.contrib.sessions.middleware import SessionMiddleware
from django.contrib.auth.middleware import AuthenticationMiddleware

from .mfa_middleware import RequireMfaSessionMiddleware, SESSION_VERIFIED, SESSION_EPOCH
from .mfa_session_revocation import revoke_mfa_sessions
from .models import UserMfaState


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
