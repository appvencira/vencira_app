"""G4 candidate acceptance tests: disposable DB, no installed mobile routes.

Run ONLY with VENCIRA_ENV=test VENCIRA_NATIVE_SERVICE_CANDIDATE=1
against a disposable PostgreSQL17 instance or temporary SQLite test DB.
"""
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import Client, TestCase, override_settings
from django.urls import Resolver404, resolve
from django.utils import timezone

from reminders.models import Renewal, UserMfaState, Workspace, WorkspaceMember
from .models import MobileAccountFence, MobileDeviceSession, MobileSpentRefresh
from .session_store import (
    MobileTokenDenied, issue_verified_candidate_session,
    revoke_all_candidate_devices, revoke_candidate_device,
    rotate_candidate_refresh,
)


@override_settings(ROOT_URLCONF="native_mobile_service.test_urls",
                   VENCIRA_NATIVE_BEARER_ENABLED=True)
class MobileCandidateContractTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.owner = User.objects.create_user(
            username="candidate-owner", password="SyntheticPasswordG4-2026",
        )
        cls.member = User.objects.create_user(
            username="candidate-member", password="SyntheticPasswordG4-2026",
        )
        cls.other = User.objects.create_user(
            username="candidate-other", password="SyntheticPasswordG4-2026",
        )
        cls.ws = Workspace.objects.create(name="Candidate A")
        cls.foreign = Workspace.objects.create(name="Candidate B")
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.owner, role="owner",
        )
        WorkspaceMember.objects.create(
            workspace=cls.ws, user=cls.member, role="member",
        )
        WorkspaceMember.objects.create(
            workspace=cls.foreign, user=cls.other, role="owner",
        )
        cls.assigned = Renewal.objects.create(
            workspace=cls.ws, assigned_to=cls.member,
            customer_reference="secret-assigned-xyz",
            full_name="customer-privacy-name",
            expires_on=date(2030, 1, 3),
        )
        cls.unassigned = Renewal.objects.create(
            workspace=cls.ws, assigned_to=None,
            customer_reference="secret-unassigned-xyz",
            expires_on=date(2030, 1, 4),
        )
        cls.foreign_renewal = Renewal.objects.create(
            workspace=cls.foreign, assigned_to=cls.other,
            customer_reference="secret-foreign-xyz",
            expires_on=date(2030, 1, 5),
        )

    def setUp(self):
        self.client = Client(enforce_csrf_checks=True)

    def tokens(self, user=None, *, mfa=False, mfa_epoch=None, generation=0):
        user = user or self.owner
        return issue_verified_candidate_session(
            user_id=user.pk, verified_mfa=mfa,
            mfa_epoch=mfa_epoch, expected_generation=generation,
        )

    def get(self, path, access=None, **extra):
        headers = {"HTTP_AUTHORIZATION": "Bearer " + access} if access else {}
        return self.client.get(path, secure=True, **headers, **extra)

    def test_candidate_bearer_validates_opaque_access_only(self):
        access, refresh = self.tokens()
        reply = self.get("/api/v1/mobile/me/", access)
        self.assertEqual(reply.status_code, 200)
        self.assertEqual(reply.json()["user_id"], self.owner.pk)
        self.assertIn("no-store", reply["Cache-Control"])
        self.assertEqual(self.get("/api/v1/mobile/me/", refresh).status_code, 401)
        self.assertEqual(self.get("/api/v1/mobile/me/").status_code, 401)
        row = MobileDeviceSession.objects.get()
        self.assertNotIn(access, row.access_digest)
        self.assertNotIn(refresh, row.refresh_digest)
        self.assertEqual(len(row.access_digest), 64)
        self.assertEqual(len(row.refresh_digest), 64)

    def test_owner_and_member_scopes_reuse_operational_permissions(self):
        owner_access, _ = self.tokens()
        path = f"/api/v1/mobile/workspaces/{self.ws.pk}/renewals/"
        owner_reply = self.get(path, owner_access)
        self.assertEqual(owner_reply.status_code, 200)
        self.assertEqual(
            {entry["id"] for entry in owner_reply.json()["results"]},
            {str(self.assigned.pk), str(self.unassigned.pk)},
        )
        self.assertNotIn("secret-", owner_reply.content.decode())
        self.assertNotIn("customer-privacy-name", owner_reply.content.decode())
        member_access, _ = self.tokens(self.member)
        member_reply = self.get(path, member_access)
        self.assertEqual(member_reply.status_code, 200)
        self.assertEqual(
            [entry["id"] for entry in member_reply.json()["results"]],
            [str(self.assigned.pk)],
        )
        self.assertEqual(self.get(
            f"/api/v1/mobile/workspaces/{self.foreign.pk}/renewals/",
            member_access,
        ).status_code, 404)

    def test_membership_deleted_invalidates_workspace_access_immediately(self):
        access, _ = self.tokens(self.member)
        path = f"/api/v1/mobile/workspaces/{self.ws.pk}/renewals/"
        self.assertEqual(self.get(path, access).status_code, 200)
        WorkspaceMember.objects.filter(
            workspace=self.ws, user=self.member,
        ).delete()
        self.assertEqual(self.get(path, access).status_code, 404)

    def test_bearer_never_accepts_web_cookie_origin_or_insecure_http(self):
        access, _ = self.tokens()
        path = "/api/v1/mobile/me/"
        self.assertEqual(self.get(
            path, access, HTTP_ORIGIN="https://evil.example",
        ).status_code, 401)
        self.assertEqual(self.get(
            path, access, HTTP_COOKIE="vencira_sessionid=synthetic",
        ).status_code, 401)
        self.assertEqual(self.get(
            path, access, HTTP_REFERER="https://evil.example",
        ).status_code, 401)
        self.assertEqual(
            self.client.get(path, HTTP_AUTHORIZATION="Bearer " + access).status_code,
            401,
        )

    def test_ambient_browser_session_never_substitutes_for_native_bearer(self):
        self.client.force_login(self.owner)
        self.assertEqual(self.client.get(
            "/api/v1/mobile/me/", secure=True,
        ).status_code, 401)

    @override_settings(VENCIRA_NATIVE_BEARER_ENABLED=False)
    def test_mobile_bearer_disabled_even_when_token_is_valid(self):
        access, _ = self.tokens()
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", access,
        ).status_code, 401)

    @override_settings(VENCIRA_ENV="production")
    def test_candidate_denied_when_environment_is_not_test(self):
        # No runtime setting can turn candidate routes into production auth.
        # This is a direct override test; production cannot install the app.
        self.assertEqual(self.get(
            "/api/v1/mobile/me/",
            "v1.a.0123456789abcdef0123456789abcdef."
            + "A" * 43,
        ).status_code, 401)

    def test_tampering_and_query_parameters_fail_closed(self):
        access, _ = self.tokens()
        self.assertEqual(self.get(
            "/api/v1/mobile/me/?x=1", access,
        ).status_code, 400)
        altered = access[:-1] + ("Q" if access[-1] != "Q" else "A")
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", altered,
        ).status_code, 401)
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", access + "junk",
        ).status_code, 401)

    def test_refresh_rotation_and_known_replay_revoke_device(self):
        old_access, old_refresh = self.tokens()
        new_access, new_refresh = rotate_candidate_refresh(old_refresh)
        self.assertNotEqual(new_refresh, old_refresh)
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", old_access,
        ).status_code, 401)
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", new_access,
        ).status_code, 200)
        self.assertEqual(MobileSpentRefresh.objects.count(), 1)
        with self.assertRaises(MobileTokenDenied):
            rotate_candidate_refresh(old_refresh)
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", new_access,
        ).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.get().refresh_digest, "")

    def test_unknown_refresh_cannot_revoke_current_session(self):
        access, refresh = self.tokens()
        tampered = refresh[:-1] + ("Q" if refresh[-1] != "Q" else "A")
        with self.assertRaises(MobileTokenDenied):
            rotate_candidate_refresh(tampered)
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 200)

    def test_device_and_account_wide_revocation(self):
        first, refresh1 = self.tokens()
        second, _ = self.tokens()
        revoke_candidate_device(refresh1)
        self.assertEqual(self.get("/api/v1/mobile/me/", first).status_code, 401)
        self.assertEqual(self.get("/api/v1/mobile/me/", second).status_code, 200)
        self.assertEqual(revoke_all_candidate_devices(user_id=self.owner.pk), 1)
        self.assertEqual(self.get("/api/v1/mobile/me/", second).status_code, 401)
        self.assertEqual(MobileAccountFence.objects.get(
            user_id=self.owner.pk,
        ).generation, 1)
        renewed, _ = self.tokens(generation=1)
        self.assertEqual(self.get("/api/v1/mobile/me/", renewed).status_code, 200)

    def test_password_change_invalidates_native_access(self):
        access, _ = self.tokens()
        self.owner.set_password("NewSyntheticPasswordG4-2026")
        self.owner.save(update_fields=["password"])
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 401)

    def test_expired_access_is_rejected_before_data(self):
        access, _ = self.tokens()
        MobileDeviceSession.objects.update(
            access_expires_at=timezone.now() - timedelta(seconds=1),
        )
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 401)

    def test_mfa_epoch_is_checked_for_every_api_request(self):
        UserMfaState.objects.create(
            user=self.owner, enabled=True, session_epoch=7,
            encrypted_totp_secret="not-used-in-this-authentication-test",
        )
        access, _ = self.tokens(self.owner, mfa=True, mfa_epoch=7)
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 200)
        state = UserMfaState.objects.get(user=self.owner)
        state.session_epoch = 8
        state.save(update_fields=["session_epoch"])
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 401)

    def test_inactive_account_cannot_use_or_refresh_previous_device(self):
        access, refresh = self.tokens()
        self.owner.is_active = False
        self.owner.save(update_fields=["is_active"])
        self.assertEqual(self.get("/api/v1/mobile/me/", access).status_code, 401)
        with self.assertRaises(MobileTokenDenied):
            rotate_candidate_refresh(refresh)

    def test_password_change_invalidates_refresh_before_rotation(self):
        _, refresh = self.tokens()
        self.owner.set_password("RotatedSyntheticPasswordG4-2026")
        self.owner.save(update_fields=["password"])
        with self.assertRaises(MobileTokenDenied):
            rotate_candidate_refresh(refresh)
        self.assertFalse(MobileSpentRefresh.objects.exists())

    def test_old_generation_cannot_issue_after_account_wide_revoke(self):
        old_access, _ = self.tokens()
        revoke_all_candidate_devices(user_id=self.owner.pk)
        with self.assertRaises(MobileTokenDenied):
            self.tokens(generation=0)
        self.assertEqual(self.get(
            "/api/v1/mobile/me/", old_access,
        ).status_code, 401)
        self.assertEqual(MobileDeviceSession.objects.count(), 1)

    @override_settings(ROOT_URLCONF="config.urls")
    def test_candidate_routes_not_exposed_in_operational_urlconf(self):
        from django.urls import clear_url_caches
        try:
            clear_url_caches()
            with self.assertRaises(Resolver404):
                resolve("/api/v1/mobile/me/")
        finally:
            clear_url_caches()
