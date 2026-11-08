"""I8-K recovery HTTP contract against disposable PostgreSQL17 only."""
import json
import os
import time
import uuid
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, resolve

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState

from .candidate_two_step_issuer import (
    candidate_password_to_challenge, candidate_mfa_challenge_to_session,
)
from .models import MobileAccountFence, MobileDeviceSession, MobilePendingChallenge


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_i8k_recovery_urls",
    VENCIRA_G5_ABUSE_KEY="i8k-disposable-abuse-only-postgres17",
    VENCIRA_G5_AUDIT_KEY="i8k-disposable-audit-only-postgres17",
)
class I8KRecoveryHttpPG17(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("I8-K only in disposable PG17")
        self.keys = [Fernet.generate_key().decode("ascii")]
        scope = patch.dict(os.environ, {
            "VENCIRA_I8K_RECOVERY_LAB": "1",
            "VENCIRA_I8D_MFA_KEY": self.keys[0],
        })
        scope.start()
        self.addCleanup(scope.stop)
        self.user = get_user_model().objects.create_user(
            username="i8k-synthetic", password="synthetic-i8k-password",
        )
        self.secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                self.secret, user_id=self.user.pk, keys=self.keys,
            ),
        )

    def post(self, path, data, **kwargs):
        return self.client.post(
            path, data=json.dumps(data),
            content_type="application/json", **kwargs,
        )

    def password(self, **kwargs):
        return self.post("/api/v1/mobile/auth/recover/password/", {
            "username": "i8k-synthetic", "password": "synthetic-i8k-password",
        }, **kwargs)

    def mfa(self, challenge, code=None, **kwargs):
        return self.post("/api/v1/mobile/auth/recover/mfa/", {
            "challenge": challenge,
            "code": code if code is not None else totp_at(self.secret, int(time.time())),
        }, **kwargs)

    def initial_device(self):
        challenge = candidate_password_to_challenge(
            username=self.user.username, password="synthetic-i8k-password",
            request_meta={"REMOTE_ADDR": "198.51.100.88"},
            event_id=uuid.uuid4(),
        )
        return candidate_mfa_challenge_to_session(
            wire=challenge, code=totp_at(self.secret, int(time.time()) - 30),
            keys=self.keys, event_id=uuid.uuid4(),
            timestamp=int(time.time()) - 30,
        )

    def test_http_recovery_revokes_prior_device_and_issues_one(self):
        # Start with an already-authenticated synthetic device.
        prior = self.initial_device()
        self.assertIsNotNone(prior)
        reply = self.password()
        self.assertEqual(reply.status_code, 200)
        self.assertEqual(set(reply.json()), {"status", "challenge"})
        self.assertNotIn("Set-Cookie", reply)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        result = self.mfa(reply.json()["challenge"])
        self.assertEqual(result.status_code, 200)
        self.assertEqual(set(result.json()), {"status", "access", "refresh"})
        self.assertNotIn("Set-Cookie", result)
        old_me = self.client.get("/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + prior[0])
        new_me = self.client.get("/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + result.json()["access"])
        self.assertEqual(old_me.status_code, 401)
        self.assertEqual(new_me.status_code, 200)
        self.assertEqual(MobileDeviceSession.objects.filter(
            revoked_at__isnull=True).count(), 1)
        self.assertEqual(MobileAccountFence.objects.get(user=self.user).generation, 1)

    def test_recovery_issued_refresh_can_revoke_and_access_is_denied(self):
        response = self.password()
        self.assertEqual(response.status_code, 200)
        tokens = self.mfa(response.json()["challenge"])
        self.assertEqual(tokens.status_code, 200)
        access = tokens.json()["access"]
        refresh = tokens.json()["refresh"]
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + access,
        ).status_code, 200)
        revoked = self.post("/api/v1/mobile/token/revoke/", {
            "refresh": refresh,
        })
        self.assertEqual(revoked.status_code, 200)
        self.assertEqual(revoked.json(), {"status": "revoked"})
        self.assertNotIn("Set-Cookie", revoked)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + access,
        ).status_code, 401)
        self.assertEqual(self.post("/api/v1/mobile/token/revoke/", {
            "refresh": refresh,
        }).status_code, 401)

    def test_revoke_only_own_device_preserves_other_account(self):
        # The token itself selects the session; request JSON must never
        # carry a user_id or an account-wide revocation capability.
        second = get_user_model().objects.create_user(
            username="i8k-second-account",
            password="synthetic-second-account-password",
        )
        second_secret = generate_secret()
        UserMfaState.objects.create(
            user=second, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                second_secret, user_id=second.pk, keys=self.keys,
            ),
        )
        second_challenge = candidate_password_to_challenge(
            username=second.username,
            password="synthetic-second-account-password",
            request_meta={"REMOTE_ADDR": "198.51.100.89"},
            event_id=uuid.uuid4(),
        )
        self.assertIsNotNone(second_challenge)
        second_pair = candidate_mfa_challenge_to_session(
            wire=second_challenge,
            code=totp_at(second_secret, int(time.time()) - 30),
            keys=self.keys, event_id=uuid.uuid4(),
            timestamp=int(time.time()) - 30,
        )
        self.assertIsNotNone(second_pair)

        own_challenge = self.password()
        self.assertEqual(own_challenge.status_code, 200)
        own_tokens = self.mfa(own_challenge.json()["challenge"])
        self.assertEqual(own_tokens.status_code, 200)
        self.assertEqual(self.post("/api/v1/mobile/token/revoke/", {
            "refresh": own_tokens.json()["refresh"],
        }).status_code, 200)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + own_tokens.json()["access"],
        ).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + second_pair[0],
        ).status_code, 200)
        self.assertEqual(MobileDeviceSession.objects.filter(
            user=second, revoked_at__isnull=True,
        ).count(), 1)

    def test_revoked_old_refresh_cannot_revoke_new_recovery(self):
        prior = self.initial_device()
        self.assertIsNotNone(prior)
        challenge = self.password()
        self.assertEqual(challenge.status_code, 200)
        issued = self.mfa(challenge.json()["challenge"])
        self.assertEqual(issued.status_code, 200)
        self.assertEqual(self.post("/api/v1/mobile/token/revoke/", {
            "refresh": prior[1],
        }).status_code, 401)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + issued.json()["access"],
        ).status_code, 200)
        self.assertEqual(MobileDeviceSession.objects.filter(
            user=self.user, revoked_at__isnull=True,
        ).count(), 1)

    def test_recovery_revoke_rejects_invalid_token_and_browser_metadata(self):
        route = "/api/v1/mobile/token/revoke/"
        self.assertEqual(self.post(route, {"refresh": "not-a-token"}).status_code, 401)
        self.assertEqual(self.post(route, {"refresh": "not-a-token", "other": "x"}).status_code, 400)
        self.assertEqual(self.client.get(route).status_code, 405)
        for meta in (
            {"HTTP_COOKIE": "sessionid=synthetic"},
            {"HTTP_ORIGIN": "https://untrusted.invalid"},
            {"HTTP_AUTHORIZATION": "Bearer synthetic"},
        ):
            with self.subTest(meta=meta):
                self.assertEqual(self.post(route, {
                    "refresh": "not-a-token",
                }, **meta).status_code, 403)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_password_only_does_not_revoke_or_issue(self):
        old = self.initial_device()
        result = self.password()
        self.assertEqual(result.status_code, 200)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)
        self.assertEqual(self.client.get("/api/v1/mobile/me/",
            HTTP_AUTHORIZATION="Bearer " + old[0]).status_code, 200)

    def test_bad_totp_denied_without_revoke(self):
        result = self.password()
        valid = totp_at(self.secret, int(time.time()))
        wrong = "000000" if valid != "000000" else "111111"
        self.assertEqual(self.mfa(result.json()["challenge"], wrong).status_code, 401)
        self.assertFalse(MobileDeviceSession.objects.exists())
        self.assertFalse(MobileAccountFence.objects.exists())

    def test_cross_purpose_and_replay_denied(self):
        # Ordinary login route is absent in recovery-only URLconf.
        for endpoint in (
            "/api/v1/mobile/auth/password/",
            "/api/v1/mobile/auth/mfa/",
            "/api/v1/mobile/token/refresh/",
        ):
            with self.assertRaises(Resolver404):
                resolve(endpoint)
        challenge = self.password().json()["challenge"]
        self.assertEqual(self.mfa(challenge).status_code, 200)
        self.assertEqual(self.mfa(challenge).status_code, 401)

    def test_cookie_origin_and_post_authorization_denied(self):
        for extra in (
            {"HTTP_COOKIE": "vencira_sessionid=bad"},
            {"HTTP_ORIGIN": "https://untrusted.invalid"},
            {"HTTP_AUTHORIZATION": "Bearer arbitrary"},
        ):
            with self.subTest(extra=extra):
                response = self.password(**extra)
                self.assertEqual(response.status_code, 403)
                self.assertFalse(MobilePendingChallenge.objects.exists())

    def test_malformed_payload_and_wrong_method(self):
        self.assertEqual(self.post(
            "/api/v1/mobile/auth/recover/mfa/",
            {"challenge": "broken", "code": "000000", "other": "x"},
        ).status_code, 400)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/auth/recover/password/",
        ).status_code, 405)

    def test_guards_fail_closed_and_no_operational_routes(self):
        with override_settings(VENCIRA_NATIVE_SERVICE_CANDIDATE=False):
            self.assertEqual(self.password().status_code, 404)
        with patch.dict(os.environ, {"VENCIRA_I8K_RECOVERY_LAB": "0"}):
            self.assertEqual(self.password().status_code, 404)
        with override_settings(ROOT_URLCONF="config.urls"):
            for route in (
                "/api/v1/mobile/auth/recover/password/",
                "/api/v1/mobile/auth/recover/mfa/",
                "/api/v1/mobile/token/revoke/",
            ):
                with self.assertRaises(Resolver404):
                    resolve(route)
        self.assertFalse(MobileDeviceSession.objects.exists())

    def test_no_mfa_account_is_uniformly_denied(self):
        self.user.vencira_mfa.enabled = False
        self.user.vencira_mfa.save(update_fields=["enabled"])
        result = self.password()
        self.assertEqual(result.status_code, 401)
        self.assertEqual(result.json(), {"error": "native_auth_unavailable"})
        self.assertFalse(MobileDeviceSession.objects.exists())
