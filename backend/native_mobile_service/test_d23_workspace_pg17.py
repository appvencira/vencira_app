"""D23 live native tenant/assignment fences over PG17 and isolated HTTP."""
from datetime import date
import os
import time
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, clear_url_caches, resolve

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import Renewal, UserMfaState, Workspace, WorkspaceMember

from .native_server_custody_issuer import (
    begin_native_password, complete_native_mfa,
)


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_d22_urls",
    VENCIRA_G5_ABUSE_KEY="d23-ephemeral-abuse-gate-postgres",
    VENCIRA_G5_AUDIT_KEY="d23-ephemeral-audit-gate-postgres",
)
class D23NativeWorkspacePG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D23 requires disposable PostgreSQL17")
        key = Fernet.generate_key().decode("ascii")
        self.environ = patch.dict(os.environ, {
            "VENCIRA_D22_HTTP_LAB": "1",
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        })
        self.environ.start()
        self.addCleanup(self.environ.stop)
        self.user = get_user_model().objects.create_user(
            username="d23-synthetic-member", password="d23-test-password",
        )
        self.other = get_user_model().objects.create_user(
            username="d23-synthetic-other", password="d23-other-password",
        )
        secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                secret, user_id=self.user.pk, keys=[key],
            ),
        )
        self.a = Workspace.objects.create(name="D23 A")
        self.b = Workspace.objects.create(name="D23 B")
        self.member = WorkspaceMember.objects.create(
            workspace=self.a, user=self.user,
            role=WorkspaceMember.Role.MEMBER,
        )
        WorkspaceMember.objects.create(
            workspace=self.b, user=self.other,
            role=WorkspaceMember.Role.OWNER,
        )
        self.mine = Renewal.objects.create(
            workspace=self.a, assigned_to=self.user,
            expires_on=date(2027, 1, 1), customer_reference="D23 mine",
        )
        self.not_mine = Renewal.objects.create(
            workspace=self.a, assigned_to=self.other,
            expires_on=date(2027, 1, 2), customer_reference="D23 hidden",
        )
        self.foreign = Renewal.objects.create(
            workspace=self.b, assigned_to=self.other,
            expires_on=date(2027, 1, 3), customer_reference="D23 foreign",
        )
        challenge = begin_native_password(
            username=self.user.username, password="d23-test-password",
            request_meta={"REMOTE_ADDR": "198.51.100.42"},
        )
        self.access, self.refresh = complete_native_mfa(
            challenge=challenge, code=totp_at(secret, int(time.time())),
        )

    def url(self, ws):
        return f"/api/v1/mobile/workspaces/{ws.pk}/renewals/"

    def read(self, ws, *, token=None, **headers):
        return self.client.get(
            self.url(ws), secure=True,
            HTTP_AUTHORIZATION="Bearer " + (
                self.access if token is None else token
            ), **headers,
        )

    def test_member_sees_only_current_assignment_without_pii(self):
        response = self.read(self.a)
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["workspace_id"], str(self.a.pk))
        self.assertEqual(body["results"], [{
            "id": str(self.mine.pk), "expires_on": "2027-01-01",
            "status": "pending",
        }])
        self.assertNotIn("customer_reference", str(body))
        self.assertNotIn("Set-Cookie", response)
        self.assertEqual(response["Cache-Control"], "no-store, max-age=0")
        print("D23_NATIVE_MEMBER_ASSIGNMENT_SCOPE=PASS")

    def test_cross_workspace_and_invalid_token_denied(self):
        self.assertEqual(self.read(self.b).status_code, 401)
        self.assertEqual(self.read(self.a, token="synthetic-bad").status_code, 401)
        self.assertEqual(self.read(self.a, HTTP_COOKIE="sessionid=fake").status_code, 403)
        print("D23_NATIVE_CROSS_WORKSPACE_DENIED=PASS")

    def test_membership_and_assignment_change_take_effect_same_token(self):
        self.assertEqual(len(self.read(self.a).json()["results"]), 1)
        self.mine.assigned_to = self.other
        self.mine.save(update_fields=["assigned_to"])
        self.assertEqual(self.read(self.a).json()["results"], [])
        self.not_mine.assigned_to = self.user
        self.not_mine.save(update_fields=["assigned_to"])
        self.assertEqual(
            [x["id"] for x in self.read(self.a).json()["results"]],
            [str(self.not_mine.pk)],
        )
        self.member.role = WorkspaceMember.Role.OWNER
        self.member.save(update_fields=["role"])
        self.assertEqual(len(self.read(self.a).json()["results"]), 2)
        self.member.delete()
        self.assertEqual(self.read(self.a).status_code, 401)
        print("D23_NATIVE_LIVE_MEMBERSHIP_AND_ASSIGNMENT_FENCE=PASS")

    def test_native_workspace_http_offset_and_canonical_page(self):
        request_path = self.url(self.a)
        for suffix in ("?offset=1", "?offset=-50", "?offset=050",
                       "?offset=10050", "?offset=not-a-number"):
            with self.subTest(suffix=suffix):
                response = self.client.get(
                    request_path + suffix, secure=True,
                    HTTP_AUTHORIZATION="Bearer " + self.access,
                )
                self.assertEqual(response.status_code, 400)
        page = self.client.get(
            request_path + "?offset=50", secure=True,
            HTTP_AUTHORIZATION="Bearer " + self.access,
        )
        self.assertEqual(page.status_code, 200)
        self.assertEqual(page.json()["results"], [])
        self.assertIsNone(page.json()["next_offset"])
        print("D24_WORKSPACE_HTTP_OFFSET_FENCE=PASS")

    def test_no_native_workspace_route_in_operational_urlconf(self):
        from django.test import override_settings as override
        with override(ROOT_URLCONF="config.urls"):
            clear_url_caches()
            try:
                with self.assertRaises(Resolver404):
                    resolve(self.url(self.a))
            finally:
                clear_url_caches()
        print("D23_OPERATIONAL_WORKSPACE_ROUTE_ABSENT=PASS")
