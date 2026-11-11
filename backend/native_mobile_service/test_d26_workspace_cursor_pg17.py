"""D26 isolated PG17 cursor contract, stable immutable order and live scope."""
import os
import time
from datetime import date, timedelta
from unittest.mock import patch

from cryptography.fernet import Fernet
from django.contrib.auth import get_user_model
from django.db import connection, transaction
from django.test import TransactionTestCase, override_settings
from django.urls import Resolver404, clear_url_caches, resolve

from reminders.mfa_secrets import encrypt_totp_secret
from reminders.mfa_totp import generate_secret, totp_at
from reminders.models import Renewal, UserMfaState, Workspace, WorkspaceMember
from .native_server_custody_issuer import begin_native_password, complete_native_mfa
from .native_workspace_cursor import NativeCursorDenied, read_native_cursor_page


@override_settings(
    ROOT_URLCONF="native_mobile_service.test_d22_urls",
    VENCIRA_G5_ABUSE_KEY="d26-isolated-abuse-key",
    VENCIRA_G5_AUDIT_KEY="d26-isolated-audit-key",
)
class D26SignedCursorPG17Tests(TransactionTestCase):
    def setUp(self):
        if connection.vendor != "postgresql":
            self.skipTest("D26 only on isolated PG17")
        key = Fernet.generate_key().decode("ascii")
        env = patch.dict(os.environ, {
            "VENCIRA_D22_HTTP_LAB": "1",
            "VENCIRA_MFA_FERNET_KEYS": key,
            "VENCIRA_MFA_FERNET_KEYS_FILE": "",
        })
        env.start()
        self.addCleanup(env.stop)
        self.user = get_user_model().objects.create_user(
            username="d26-reader", password="d26-test-password",
        )
        self.other = get_user_model().objects.create_user(
            username="d26-other", password="d26-other-password",
        )
        secret = generate_secret()
        UserMfaState.objects.create(
            user=self.user, enabled=True, session_epoch=1,
            encrypted_totp_secret=encrypt_totp_secret(
                secret, user_id=self.user.pk, keys=[key],
            ),
        )
        self.a = Workspace.objects.create(name="D26-A")
        self.b = Workspace.objects.create(name="D26-B")
        self.member = WorkspaceMember.objects.create(
            workspace=self.a, user=self.user,
            role=WorkspaceMember.Role.MEMBER,
        )
        WorkspaceMember.objects.create(
            workspace=self.b, user=self.other,
            role=WorkspaceMember.Role.OWNER,
        )
        challenge = begin_native_password(
            username=self.user.username, password="d26-test-password",
            request_meta={"REMOTE_ADDR": "198.51.100.60"},
        )
        self.access, self.refresh = complete_native_mfa(
            challenge=challenge, code=totp_at(secret, int(time.time())),
        )
        self.rows = [
            Renewal.objects.create(
                workspace=self.a, assigned_to=self.user,
                customer_reference=f"D26 synthetic {i}",
                expires_on=date(2027, 1, 1) + timedelta(days=i),
            )
            for i in range(75)
        ]
        self.path = f"/api/v1/mobile/workspaces/{self.a.pk}/renewals/cursor/"

    def request(self, cursor=None, path=None):
        kwargs = {} if cursor is None else {"cursor": cursor}
        return self.client.get(
            self.path if path is None else path,
            data=kwargs, secure=True,
            HTTP_AUTHORIZATION="Bearer " + self.access,
        )

    def test_modified_dates_and_status_cannot_duplicate_rows_between_pages(self):
        first = self.request()
        self.assertEqual(first.status_code, 200)
        first_data = first.json()
        self.assertEqual(len(first_data["results"]), 50)
        self.assertIsInstance(first_data["next_cursor"], str)
        for row in self.rows[:50]:
            row.expires_on = date(2035, 12, 31)
            row.status = Renewal.Status.CONTACTED
            row.save(update_fields=["expires_on", "status"])
        newly_added = Renewal.objects.create(
            workspace=self.a, assigned_to=self.user,
            customer_reference="D26 created after first page",
            expires_on=date(2027, 1, 1),
        )
        second = self.request(first_data["next_cursor"])
        self.assertEqual(second.status_code, 200)
        second_data = second.json()
        self.assertEqual(len(second_data["results"]), 25)
        self.assertIsNone(second_data["next_cursor"])
        all_ids = [item["id"] for item in first_data["results"] + second_data["results"]]
        self.assertEqual(len(set(all_ids)), 75)
        self.assertNotIn(str(newly_added.pk), all_ids)
        self.assertEqual(
            set(all_ids), {str(row.pk) for row in self.rows},
        )
        print("D26_CURSOR_STABLE_UNDER_DATE_STATUS_AND_INSERTS_PG17=PASS")

    def test_tamper_cross_tenant_and_expiration_denied(self):
        cursor = self.request().json()["next_cursor"]
        self.assertTrue(cursor)
        self.assertEqual(self.request(cursor + "x").status_code, 401)
        foreign_path = f"/api/v1/mobile/workspaces/{self.b.pk}/renewals/cursor/"
        self.assertEqual(self.request(cursor, foreign_path).status_code, 401)
        with transaction.atomic():
            with self.assertRaises(NativeCursorDenied):
                read_native_cursor_page(
                    user=self.other, workspace_id=self.a.pk, cursor=cursor,
                )
        with patch("django.core.signing.time.time", return_value=time.time() + 1000):
            self.assertEqual(self.request(cursor).status_code, 401)
        print("D26_CURSOR_TAMPER_TENANT_AND_EXPIRY_DENIED=PASS")

    def test_member_revocation_applies_to_next_cursor_request(self):
        cursor = self.request().json()["next_cursor"]
        self.member.delete()
        self.assertEqual(self.request(cursor).status_code, 401)
        print("D26_CURSOR_MEMBERSHIP_RECHECK=PASS")

    def test_cursor_input_shape_and_absent_operational_route(self):
        for query in ("?cursor=", "?cursor=unsafe%20token", "?cursor=foo&cursor=bar",
                      "?offset=50", "?cursor=" + "x" * 1025):
            response = self.client.get(
                self.path + query, secure=True,
                HTTP_AUTHORIZATION="Bearer " + self.access,
            )
            self.assertEqual(response.status_code, 400, query)
        with override_settings(ROOT_URLCONF="config.urls"):
            clear_url_caches()
            try:
                with self.assertRaises(Resolver404):
                    resolve(self.path)
            finally:
                clear_url_caches()
        print("D26_CURSOR_INPUT_AND_PUBLIC_ROUTE_FENCED=PASS")
