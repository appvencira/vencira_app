"""HTTP exchange tests against an isolated URLConf and disposable test DB.

No test creates a mobile route under config.urls/reminders.urls. No live DB.
"""
import json
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.test import Client, RequestFactory, TestCase, override_settings
from django.utils import timezone

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import UserMfaState
from . import test_http_contract as lab_http
from .models import MobileDeviceSessionLab
from reminders.models import Renewal, Workspace, WorkspaceMember
from datetime import date

PASSWORD = "SyntheticPasswordOnlyForHttpLab-2026!"
PASSWORD_PATH = "/api/v1/mobile/auth/password/"
MFA_PATH = "/api/v1/mobile/auth/mfa/"
REFRESH_PATH = "/api/v1/mobile/token/refresh/"
REVOKE_PATH = "/api/v1/mobile/token/revoke/"
ME_PATH = "/api/v1/mobile/me/"


@override_settings(ROOT_URLCONF="native_sessions_lab.test_urls")
class NativeHttpContractTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = get_user_model().objects.create_user(
            username="n1-http-contract-user", password=PASSWORD,
        )

    def setUp(self):
        # CSRF exemption is deliberate ONLY in the isolated native test app.
        # Native requests do not rely on a Django browser session or cookie.
        self.client = Client(enforce_csrf_checks=True)

    def post(self, path, value, **extra):
        return self.client.post(
            path, data=json.dumps(value),
            content_type="application/json", **extra,
        )

    def password(self):
        return self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": PASSWORD,
        })

    def test_password_issued_tokens_authenticate_only_with_bearer_access(self):
        response = self.password()
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["status"], "authenticated")
        self.assertTrue(data["access"].startswith("v1.a."))
        self.assertTrue(data["refresh"].startswith("v1.r."))
        self.assertNotIn("Set-Cookie", response)
        self.assertIn("no-store", response["Cache-Control"])
        me = self.client.get(
            ME_PATH, HTTP_AUTHORIZATION="Bearer " + data["access"],
        )
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.json()["user_id"], self.user.pk)
        self.assertEqual(
            self.client.get(
                ME_PATH, HTTP_AUTHORIZATION="Bearer " + data["refresh"],
            ).status_code, 401,
        )
        self.assertEqual(self.client.get(ME_PATH).status_code, 401)

    def test_refresh_rotates_access_and_replay_revokes_device(self):
        data = self.password().json()
        rotated = self.post(REFRESH_PATH, {
            "refresh": data["refresh"],
        })
        self.assertEqual(rotated.status_code, 200)
        new = rotated.json()
        self.assertNotEqual(new["access"], data["access"])
        self.assertNotEqual(new["refresh"], data["refresh"])
        self.assertEqual(self.client.get(
            ME_PATH, HTTP_AUTHORIZATION="Bearer " + data["access"],
        ).status_code, 401)
        self.assertEqual(self.client.get(
            ME_PATH, HTTP_AUTHORIZATION="Bearer " + new["access"],
        ).status_code, 200)
        self.assertEqual(self.post(REFRESH_PATH, {
            "refresh": data["refresh"],
        }).status_code, 401)
        self.assertEqual(self.client.get(
            ME_PATH, HTTP_AUTHORIZATION="Bearer " + new["access"],
        ).status_code, 401)

    def test_revoke_disables_existing_device_and_repeat_denied(self):
        data = self.password().json()
        response = self.post(REVOKE_PATH, {"refresh": data["refresh"]})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "revoked"})
        self.assertEqual(self.client.get(
            ME_PATH, HTTP_AUTHORIZATION="Bearer " + data["access"],
        ).status_code, 401)
        self.assertEqual(self.post(
            REVOKE_PATH, {"refresh": data["refresh"]},
        ).status_code, 401)

    def test_password_errors_do_not_issue_or_disclose_identifiers(self):
        failure = self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": "incorrect",
        })
        self.assertEqual(failure.status_code, 401)
        self.assertEqual(failure.json(), {
            "error": "native_auth_unavailable",
        })
        self.assertFalse(MobileDeviceSessionLab.objects.exists())
        for _ in range(4):
            self.post(PASSWORD_PATH, {
                "username": self.user.username, "password": "incorrect",
            })
        self.assertEqual(self.password().status_code, 401)

    def test_post_requires_exact_json_schema_and_rejects_oversize(self):
        response = self.client.post(PASSWORD_PATH, data="username=x",
                                    content_type="text/plain")
        self.assertEqual(response.status_code, 400)
        self.assertEqual(self.post(PASSWORD_PATH, {
            "username": self.user.username,
            "password": PASSWORD,
            "admin": True,
        }).status_code, 400)
        self.assertEqual(self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": True,
        }).status_code, 400)
        self.assertEqual(self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": "A" * 6000,
        }).status_code, 400)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    def test_method_origin_and_cookie_fail_closed(self):
        self.assertEqual(self.client.get(PASSWORD_PATH).status_code, 405)
        self.assertEqual(self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": PASSWORD,
        }, HTTP_ORIGIN="https://attacker.example").status_code, 403)
        self.assertEqual(self.post(PASSWORD_PATH, {
            "username": self.user.username, "password": PASSWORD,
        }, HTTP_COOKIE="vencira_sessionid=synthetic").status_code, 403)
        # With enforce_csrf_checks=True, Django rejects unsafe POST
        # before the GET-only view can return its own method denial.
        self.assertEqual(
            self.client.post(
                ME_PATH, {}, content_type="application/json",
            ).status_code,
            403,
        )
        # The view itself still rejects POST as method not allowed when
        # exercised without middleware. Do NOT exempt /me/ from CSRF.
        request = RequestFactory().post(
            ME_PATH, data="{}", content_type="application/json",
        )
        self.assertEqual(lab_http.me(request).status_code, 405)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())

    @override_settings(ROOT_URLCONF="config.urls")
    def test_experimental_paths_absent_from_operational_urlconf_even_in_lab(self):
        from django.urls import Resolver404, resolve

        for path in (
            PASSWORD_PATH, MFA_PATH, REFRESH_PATH,
            REVOKE_PATH, ME_PATH,
            "/api/v1/mobile/workspaces/00000000-0000-0000-0000-000000000001/renewals/",
        ):
            with self.subTest(path=path), self.assertRaises(Resolver404):
                resolve(path)

    @override_settings(VENCIRA_NATIVE_SESSION_LAB=False)
    def test_standalone_views_denied_if_lab_flag_disabled(self):
        request = RequestFactory().post(
            PASSWORD_PATH, data=json.dumps({
                "username": self.user.username, "password": PASSWORD,
            }), content_type="application/json",
        )
        response = lab_http.password(request)
        self.assertEqual(response.status_code, 404)

    @override_settings(VENCIRA_ENV="production")
    def test_standalone_views_denied_if_environment_production(self):
        request = RequestFactory().post(
            PASSWORD_PATH, data=json.dumps({
                "username": self.user.username, "password": PASSWORD,
            }), content_type="application/json",
        )
        response = lab_http.password(request)
        self.assertEqual(response.status_code, 404)

    def test_mfa_password_step_never_returns_bearer_and_consumes_challenge(self):
        key = Fernet.generate_key().decode("ascii")
        secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=7,
            encrypted_totp_secret=encrypt_totp_secret(
                secret, user_id=self.user.pk, keys=[key],
            ),
        )
        initial = self.password()
        self.assertEqual(initial.status_code, 200)
        body = initial.json()
        self.assertEqual(body["status"], "mfa_required")
        self.assertNotIn("access", body)
        self.assertNotIn("refresh", body)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())
        code = totp_at(secret, int(timezone.now().timestamp()))
        with patch.dict("os.environ", {
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        }):
            invalid = self.post(MFA_PATH, {
                "challenge": body["challenge"], "code": "not-a-code",
            })
            self.assertEqual(invalid.status_code, 401)
            granted = self.post(MFA_PATH, {
                "challenge": body["challenge"], "code": code,
            })
            self.assertEqual(granted.status_code, 200)
            self.assertEqual(granted.json()["status"], "authenticated")
            self.assertEqual(self.post(MFA_PATH, {
                "challenge": body["challenge"], "code": code,
            }).status_code, 401)
        self.assertEqual(MobileDeviceSessionLab.objects.count(), 1)

    def test_inactive_user_denied(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        self.assertEqual(self.password().status_code, 401)
        self.assertFalse(MobileDeviceSessionLab.objects.exists())


@override_settings(ROOT_URLCONF="native_sessions_lab.test_urls")
class NativeWorkspaceBearerScopeTests(TestCase):
    """Bearer is authenticated separately from workspace permission."""

    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.owner = User.objects.create_user(
            username="n1-scope-owner", password=PASSWORD,
        )
        cls.member = User.objects.create_user(
            username="n1-scope-member", password=PASSWORD,
        )
        cls.outsider = User.objects.create_user(
            username="n1-scope-outsider", password=PASSWORD,
        )
        cls.workspace = Workspace.objects.create(name="Lab workspace A")
        cls.foreign = Workspace.objects.create(name="Lab workspace B")
        WorkspaceMember.objects.create(
            workspace=cls.workspace, user=cls.owner,
            role=WorkspaceMember.Role.OWNER,
        )
        WorkspaceMember.objects.create(
            workspace=cls.workspace, user=cls.member,
            role=WorkspaceMember.Role.MEMBER,
        )
        WorkspaceMember.objects.create(
            workspace=cls.foreign, user=cls.outsider,
            role=WorkspaceMember.Role.OWNER,
        )
        cls.member_renewal = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.member,
            customer_reference="member-secret-not-in-response",
            full_name="private synthetic name",
            expires_on=date(2030, 4, 3),
        )
        cls.other_renewal = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=cls.owner,
            customer_reference="owner-secret-not-in-response",
            expires_on=date(2030, 4, 4),
        )
        cls.unassigned_renewal = Renewal.objects.create(
            workspace=cls.workspace, assigned_to=None,
            customer_reference="unassigned-secret-not-in-response",
            expires_on=date(2030, 4, 5),
        )
        cls.foreign_renewal = Renewal.objects.create(
            workspace=cls.foreign, assigned_to=cls.outsider,
            customer_reference="foreign-secret-not-in-response",
            expires_on=date(2030, 4, 6),
        )

    def setUp(self):
        self.client = Client(enforce_csrf_checks=True)

    def login(self, user):
        response = self.client.post(
            PASSWORD_PATH,
            data=json.dumps({"username": user.username, "password": PASSWORD}),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "authenticated")
        return response.json()

    def scoped(self, access, workspace=None, query=""):
        workspace = workspace or self.workspace
        return self.client.get(
            f"/api/v1/mobile/workspaces/{workspace.pk}/renewals/{query}",
            HTTP_AUTHORIZATION="Bearer " + access,
        )

    def test_owner_sees_only_own_workspace_without_pii(self):
        access = self.login(self.owner)["access"]
        response = self.scoped(access)
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["workspace_id"], str(self.workspace.pk))
        self.assertEqual(
            {row["id"] for row in data["results"]},
            {
                str(self.member_renewal.pk),
                str(self.other_renewal.pk),
                str(self.unassigned_renewal.pk),
            },
        )
        serialized = response.content.decode("utf-8")
        for private in (
            "member-secret", "owner-secret", "unassigned-secret",
            "foreign-secret", "private synthetic name",
        ):
            self.assertNotIn(private, serialized)

    def test_member_sees_only_assigned_renewals(self):
        access = self.login(self.member)["access"]
        response = self.scoped(access)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            [row["id"] for row in response.json()["results"]],
            [str(self.member_renewal.pk)],
        )

    def test_foreign_workspace_denied_even_with_valid_bearer(self):
        access = self.login(self.owner)["access"]
        response = self.scoped(access, self.foreign)
        self.assertEqual(response.status_code, 404)
        self.assertNotIn("foreign-secret", response.content.decode("utf-8"))

    def test_membership_removal_immediately_denies_existing_token(self):
        access = self.login(self.member)["access"]
        self.assertEqual(self.scoped(access).status_code, 200)
        WorkspaceMember.objects.filter(
            workspace=self.workspace, user=self.member,
        ).delete()
        self.assertEqual(self.scoped(access).status_code, 404)

    def test_revoked_token_does_not_authenticate_workspace(self):
        tokens = self.login(self.owner)
        self.assertEqual(self.scoped(tokens["access"]).status_code, 200)
        self.assertEqual(self.client.post(
            REVOKE_PATH, data=json.dumps({"refresh": tokens["refresh"]}),
            content_type="application/json",
        ).status_code, 200)
        self.assertEqual(self.scoped(tokens["access"]).status_code, 401)

    def test_refresh_token_cannot_authorize_workspace(self):
        tokens = self.login(self.owner)
        self.assertEqual(self.scoped(tokens["refresh"]).status_code, 401)
        self.assertEqual(self.client.get(
            f"/api/v1/mobile/workspaces/{self.workspace.pk}/renewals/",
        ).status_code, 401)

    def test_query_parameters_and_unknown_workspace_rejected(self):
        tokens = self.login(self.owner)
        self.assertEqual(
            self.scoped(tokens["access"], query="?limit=1000").status_code,
            400,
        )
        unknown = Workspace.objects.create(name="No member workspace")
        self.assertEqual(self.scoped(
            tokens["access"], unknown,
        ).status_code, 404)
